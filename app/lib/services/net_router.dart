import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// V5 统一网络通道（D79/R29–R30）：
/// 用户代理 > DoH 隧道（仅被污染域名）> 直连。
///
/// - DoH 客户端：JSON API（RFC 8484 的 JSON 变体），无第三方依赖；
///   端点顺序 doh.pub → AliDNS → Cloudflare → Google（逐个回退）；
/// - 本地 CONNECT 隧道：仅为被污染域名提供透明转发（端到端 TLS，不换证书）；
/// - `HttpOverrides.global` 注入：Dio / Image.network / 一切 dart:io HttpClient 自动生效。
///
/// 单例；测试环境不启动隧道（未 configure 时全部直连）。
class NetRouter {
  NetRouter._();

  static final NetRouter I = NetRouter._();

  /// 需要隧道（DNS 被污染/直连不可达）的域名后缀。
  static const List<String> tunnelHostSuffixes = <String>[
    'themoviedb.org',
    'tmdb.org',
    'openverse.org',
    'wikimedia.org',
    'wikipedia.org',
    'archive.org',
    'film-grab.com',
  ];

  /// DoH 端点（按顺序回退；doh.pub 实测可用）。
  static const List<String> dohEndpoints = <String>[
    'https://doh.pub/dns-query',
    'https://223.5.5.5/dns-query',
    'https://cloudflare-dns.com/dns-query',
    'https://dns.google/resolve',
  ];

  final List<String> _log = <String>[];
  List<String> get log => List<String>.unmodifiable(_log);

  DohResolver _resolver = DohResolver();
  DohResolver get resolver => _resolver;

  /// 测试钩子：替换 DoH 解析器（生产代码不调用）。
  void debugSetResolver(DohResolver resolver) {
    _resolver = resolver;
  }

  String _userProxy = '';
  bool _autoTunnel = true;
  bool _forceDirect = false;
  bool _overrideInstalled = false;
  ServerSocket? _server;
  int _tunnelPort = 0;
  String _lastError = '';

  /// 用户代理（http://host:port；空=未配置）。
  String get userProxy => _userProxy;
  bool get autoTunnel => _autoTunnel;
  bool get forceDirect => _forceDirect;
  bool get tunnelRunning => _server != null;
  int get tunnelPort => _tunnelPort;
  String get lastError => _lastError;

  /// 当前通道描述（设置页展示）。
  String get modeLabel {
    if (_forceDirect) return '直连（已强制）';
    if (_userProxy.isNotEmpty) return '用户代理 $_userProxy';
    if (tunnelRunning) return 'DoH 隧道（127.0.0.1:$_tunnelPort）';
    return '直连';
  }

  static bool needsTunnel(String host) {
    final String h = host.toLowerCase();
    for (final String suffix in tunnelHostSuffixes) {
      if (h == suffix || h.endsWith('.$suffix')) return true;
    }
    return false;
  }

  void _record(String message) {
    final String line =
        '${DateTime.now().toIso8601String().substring(11, 19)} $message';
    _log.add(line);
    if (_log.length > 200) _log.removeAt(0);
  }

  /// 读取设置（设置页与启动引导调用）。
  Future<void> configure({
    required String userProxy,
    bool autoTunnel = true,
    bool forceDirect = false,
    bool installOverride = true,
  }) async {
    _userProxy = _normalizeProxy(userProxy);
    _autoTunnel = autoTunnel;
    _forceDirect = forceDirect;
    if (_forceDirect || _userProxy.isNotEmpty) {
      await _stopTunnel();
    } else if (_autoTunnel) {
      await _ensureTunnel();
    } else {
      await _stopTunnel();
    }
    if (installOverride) _installOverride();
  }

  static String _normalizeProxy(String proxy) {
    final String p = proxy.trim();
    if (p.isEmpty) return '';
    if (p.startsWith('http://') || p.startsWith('https://')) return p;
    return p; // socks 等：交由系统代理软件，通道按直连处理
  }

  void _installOverride() {
    if (_overrideInstalled) return;
    _overrideInstalled = true;
    HttpOverrides.global = _RouterHttpOverrides(this);
    _record('HttpOverrides 已安装（代理/隧道全局生效）');
  }

  /// findProxy 决策：用户代理 > 隧道（被污染域名）> 直连。
  String proxyFor(Uri uri) {
    if (_forceDirect) return 'DIRECT';
    if (_userProxy.startsWith('http://') || _userProxy.startsWith('https://')) {
      final Uri? p = Uri.tryParse(_userProxy);
      if (p != null && p.host.isNotEmpty) return 'PROXY ${p.authority}';
    }
    if (tunnelRunning && needsTunnel(uri.host)) {
      return 'PROXY 127.0.0.1:$_tunnelPort';
    }
    return 'DIRECT';
  }

  Future<void> _ensureTunnel() async {
    if (!_autoTunnel || _forceDirect || _userProxy.isNotEmpty) return;
    if (_server != null) return;
    try {
      final ServerSocket server =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      _tunnelPort = server.port;
      _record('DoH 隧道已启动 127.0.0.1:$_tunnelPort');
      server.listen(_handleSocket, onError: (Object e) {
        _lastError = '$e';
        _record('隧道监听错误：$e');
      });
    } catch (e) {
      _lastError = '$e';
      _record('隧道启动失败：$e（回退直连）');
    }
  }

  Future<void> _stopTunnel() async {
    final ServerSocket? server = _server;
    _server = null;
    _tunnelPort = 0;
    if (server != null) {
      try {
        await server.close();
      } catch (_) {}
      _record('DoH 隧道已停止');
    }
  }

  /// CONNECT host:port HTTP/1.1 → DoH 解析 → 盲转发（单订阅，避免重听流）。
  void _handleSocket(Socket client) {
    client.setOption(SocketOption.tcpNoDelay, true);
    final BytesBuilder buffer = BytesBuilder(copy: false);
    Socket? upstream;
    bool established = false;
    Timer? guard;
    void fail(String reply) {
      try {
        if (reply.isNotEmpty) client.write(reply);
      } catch (_) {}
      try {
        client.destroy();
      } catch (_) {}
    }

    guard = Timer(const Duration(seconds: 10), () {
      if (!established) fail('');
    });
    client.listen((List<int> chunk) {
      if (established) {
        try {
          upstream?.add(chunk);
        } catch (_) {}
        return;
      }
      buffer.add(chunk);
      final Uint8List all = buffer.toBytes();
      final int end = _headerEnd(all);
      if (end < 0) {
        if (all.length > 16 * 1024) {
          guard?.cancel();
          fail('HTTP/1.1 431 Request Header Fields Too Large\r\n'
              'Content-Length: 0\r\nConnection: close\r\n\r\n');
        }
        return;
      }
      guard?.cancel();
      unawaited(_establish(client, all, end).then((Socket? up) {
        if (up == null) return;
        established = true;
        upstream = up;
        final Uint8List remain = all.sublist(end);
        if (remain.isNotEmpty) {
          try {
            up.add(remain);
          } catch (_) {}
        }
        up.listen(
          (List<int> data) {
            try {
              client.add(data);
            } catch (_) {}
          },
          onDone: () {
            try {
              client.destroy();
            } catch (_) {}
          },
          onError: (Object _) {
            try {
              client.destroy();
            } catch (_) {}
          },
        );
      }));
    }, onError: (Object _) {
      if (!established) fail('');
    }, onDone: () {
      if (!established) {
        try {
          upstream?.destroy();
        } catch (_) {}
      }
    });
  }

  static int _headerEnd(Uint8List bytes) {
    for (int i = 3; i < bytes.length; i++) {
      if (bytes[i - 3] == 13 &&
          bytes[i - 2] == 10 &&
          bytes[i - 1] == 13 &&
          bytes[i] == 10) {
        return i + 1;
      }
    }
    return -1;
  }

  /// 解析并建立上游连接；失败时回写错误并返回 null。
  Future<Socket?> _establish(Socket client, Uint8List all, int end) async {
    final String head = utf8.decode(all.sublist(0, end), allowMalformed: true);
    final String requestLine = head.split('\r\n').first.trim();
    final List<String> parts = requestLine.split(' ');
    if (parts.length < 2 || parts[0].toUpperCase() != 'CONNECT') {
      _reply(
          client,
          'HTTP/1.1 405 Method Not Allowed\r\n'
          'Content-Length: 0\r\nConnection: close\r\n\r\n');
      return null;
    }
    final String authority = parts[1];
    final int colon = authority.lastIndexOf(':');
    final String host = colon > 0 ? authority.substring(0, colon) : authority;
    final int port =
        colon > 0 ? (int.tryParse(authority.substring(colon + 1)) ?? 443) : 443;
    final List<String> ips = await _resolver.resolve(host);
    if (ips.isEmpty) {
      _lastError = 'DoH 解析失败：$host';
      _record('DoH 解析失败：$host');
      _reply(
          client,
          'HTTP/1.1 502 Bad Gateway\r\n'
          'Content-Length: 0\r\nConnection: close\r\n\r\n');
      return null;
    }
    Socket? upstream;
    Object? lastErr;
    for (final String ip in ips) {
      try {
        upstream = await Socket.connect(ip, port,
            timeout: const Duration(seconds: 12));
        break;
      } catch (e) {
        lastErr = e;
      }
    }
    if (upstream == null) {
      _lastError = 'TCP 连接失败：$host（$lastErr）';
      _record('TCP 连接失败：$host → $ips（$lastErr）');
      _reply(
          client,
          'HTTP/1.1 502 Bad Gateway\r\n'
          'Content-Length: 0\r\nConnection: close\r\n\r\n');
      return null;
    }
    upstream.setOption(SocketOption.tcpNoDelay, true);
    _record('隧道转发 $host:$port → ${ips.first}');
    try {
      client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
    } catch (e) {
      upstream.destroy();
      return null;
    }
    return upstream;
  }

  static void _reply(Socket client, String reply) {
    try {
      client.write(reply);
    } catch (_) {}
    try {
      client.destroy();
    } catch (_) {}
  }

  /// 统一 Dio（带重试拦截器；走全局通道）。
  ///
  /// 说明：flutter test 环境下默认关闭重试（避免 widget 测试的 pending timer），
  /// 由 [debugRetriesInTests] 显式打开（q5 网络测试使用）。
  static bool debugRetriesInTests = false;

  static bool get _isFlutterTest =>
      Platform.environment['FLUTTER_TEST'] == 'true';

  Dio dio({
    Duration connectTimeout = const Duration(seconds: 15),
    Duration receiveTimeout = const Duration(seconds: 20),
    int retries = 2,
    Map<String, dynamic>? headers,
  }) {
    final int effectiveRetries =
        (_isFlutterTest && !debugRetriesInTests) ? 0 : retries;
    final Dio d = Dio(BaseOptions(
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      sendTimeout: receiveTimeout,
      headers: headers,
    ));
    if (effectiveRetries > 0) {
      d.interceptors
          .add(_RetryInterceptor(retries: effectiveRetries, log: _record));
    }
    return d;
  }

  /// 测速：对目标 URL 发 HEAD/GET，返回 (ok, ms, detail)。
  Future<(bool, int, String)> probe(String url,
      {Duration timeout = const Duration(seconds: 12)}) async {
    final Stopwatch sw = Stopwatch()..start();
    try {
      final Dio d =
          dio(connectTimeout: timeout, receiveTimeout: timeout, retries: 0);
      final Response<Object?> r = await d.get<Object?>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (int? s) => s != null && s < 500,
          followRedirects: true,
        ),
      );
      sw.stop();
      return (true, sw.elapsedMilliseconds, 'HTTP ${r.statusCode}');
    } catch (e) {
      sw.stop();
      return (false, sw.elapsedMilliseconds, _friendlyError(e));
    }
  }

  static String _friendlyError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return '连接超时（服务不可达或被阻断）';
        case DioExceptionType.receiveTimeout:
          return '响应超时';
        case DioExceptionType.connectionError:
          return '连接失败（${e.message ?? '网络不可达'}）';
        default:
          return '${e.type.name}：${e.message ?? ''}';
      }
    }
    return '$e';
  }

  Future<void> dispose() async {
    await _stopTunnel();
    await _resolver.dispose();
  }
}

/// DoH JSON 客户端（缓存 + 并发去重 + 端点回退）。
class DohResolver {
  DohResolver({Future<String> Function(String url)? httpGet})
      : _httpGet = httpGet;

  final Future<String> Function(String url)? _httpGet;
  final Map<String, _DohCacheEntry> _cache = <String, _DohCacheEntry>{};
  final Map<String, Future<List<String>>> _inflight =
      <String, Future<List<String>>>{};
  String _activeEndpoint = '';
  Dio? _dio;

  Future<String> _defaultGet(String url) async {
    _dio ??= NetRouter.I.dio(retries: 0);
    final Response<String> r = await _dio!.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    return r.data ?? '';
  }

  Future<List<String>> resolve(String host) {
    final String key = host.toLowerCase();
    final _DohCacheEntry? cached = _cache[key];
    if (cached != null && !cached.expired) return Future.value(cached.ips);
    final Future<List<String>>? existing = _inflight[key];
    if (existing != null) return existing;
    final Future<List<String>> task = _resolveRemote(key).whenComplete(() {
      _inflight.remove(key);
    });
    _inflight[key] = task;
    return task;
  }

  Future<List<String>> _resolveRemote(String host) async {
    final List<String> order = <String>[
      if (_activeEndpoint.isNotEmpty) _activeEndpoint,
      ...NetRouter.dohEndpoints.where((String e) => e != _activeEndpoint),
    ];
    for (final String endpoint in order) {
      try {
        final (List<String> ips, int ttl) = await _query(endpoint, host);
        if (ips.isEmpty) continue;
        _activeEndpoint = endpoint;
        _cache[host] = _DohCacheEntry(ips, ttl);
        return ips;
      } catch (_) {
        continue;
      }
    }
    return const <String>[];
  }

  Future<(List<String>, int)> _query(String endpoint, String host) async {
    final String url = '$endpoint?name=${Uri.encodeQueryComponent(host)}'
        '&type=A';
    final Future<String> Function(String) getter = _httpGet ?? _defaultGet;
    final String body = await getter(url);
    final Map<String, Object?> json =
        (jsonDecode(body) as Map).cast<String, Object?>();
    final List<Object?> answers =
        json['Answer'] as List<Object?>? ?? <Object?>[];
    final List<String> ips = <String>[];
    int ttl = 600;
    for (final Object? a in answers) {
      if (a is! Map) continue;
      final Map<Object?, Object?> m = a;
      if ((m['type'] as num?)?.toInt() != 1) continue;
      final Object? data = m['data'];
      if (data is String && data.contains('.')) ips.add(data);
      final int t = (m['TTL'] as num?)?.toInt() ?? 60;
      ttl = math.min(ttl, math.max(30, t));
    }
    return (ips, ttl);
  }

  Future<void> dispose() async {
    _dio?.close(force: true);
    _dio = null;
  }
}

class _DohCacheEntry {
  _DohCacheEntry(this.ips, int ttlSeconds)
      : expiry = DateTime.now().add(Duration(seconds: ttlSeconds));
  final List<String> ips;
  final DateTime expiry;
  bool get expired => DateTime.now().isAfter(expiry);
}

/// 指数退避重试（429/5xx/超时/连接错误；最多 [retries] 次）。
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor({required this.retries, required this.log});
  final int retries;
  final void Function(String) log;

  static bool _retryable(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.response?.statusCode == 429 ||
      (e.response?.statusCode ?? 0) >= 500;

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final RequestOptions o = err.requestOptions;
    int attempt = (o.extra['retry_attempt'] as int?) ?? 0;
    DioException last = err;
    final Dio retryDio = NetRouter.I.dio(retries: 0);
    while (_retryable(last) && attempt < retries) {
      attempt++;
      final int delay = 400 * (1 << (attempt - 1)) + math.Random().nextInt(250);
      log('重试 ${o.uri.host}（第 $attempt/$retries 次，${delay}ms）');
      await Future<void>.delayed(Duration(milliseconds: delay));
      try {
        final Response<Object?> r = await retryDio.fetch<Object?>(
          o..extra['retry_attempt'] = attempt,
        );
        handler.resolve(r);
        return;
      } on DioException catch (e) {
        last = e;
      }
    }
    handler.next(last);
  }
}

class _RouterHttpOverrides extends HttpOverrides {
  _RouterHttpOverrides(this.router);
  final NetRouter router;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final HttpClient client = super.createHttpClient(context);
    client.connectionTimeout = const Duration(seconds: 15);
    client.findProxy = (Uri uri) => router.proxyFor(uri);
    return client;
  }
}
