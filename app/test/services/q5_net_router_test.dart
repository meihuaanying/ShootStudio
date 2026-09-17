import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/services/net_router.dart';

/// Q5 网络通道门禁（D79/R29–R30）：域名门控 / DoH 解析缓存与回退 /
/// CONNECT 隧道盲转发 / 重试退避。
void main() {
  // 测试环境默认关闭重试（避免 pending timer）；本文件显式打开以验证退避。
  NetRouter.debugRetriesInTests = true;

  group('域名门控与通道决策', () {
    test('被污染域名走隧道，直连可用的域名直连', () {
      expect(NetRouter.needsTunnel('api.themoviedb.org'), isTrue);
      expect(NetRouter.needsTunnel('image.tmdb.org'), isTrue);
      expect(NetRouter.needsTunnel('api.openverse.org'), isTrue);
      expect(NetRouter.needsTunnel('commons.wikimedia.org'), isTrue);
      expect(NetRouter.needsTunnel('api.pexels.com'), isFalse);
      expect(NetRouter.needsTunnel('images.pexels.com'), isFalse);
      expect(NetRouter.needsTunnel('doh.pub'), isFalse);
      expect(NetRouter.needsTunnel('example.com'), isFalse);
    });

    test('强制直连/用户代理优先级', () async {
      final NetRouter r = NetRouter.I;
      await r.configure(
          userProxy: '',
          autoTunnel: true,
          forceDirect: true,
          installOverride: false);
      expect(r.proxyFor(Uri.parse('https://api.themoviedb.org/x')), 'DIRECT');
      await r.configure(
          userProxy: 'http://127.0.0.1:7897',
          autoTunnel: true,
          forceDirect: false,
          installOverride: false);
      expect(r.proxyFor(Uri.parse('https://api.pexels.com/x')),
          'PROXY 127.0.0.1:7897');
      expect(r.proxyFor(Uri.parse('https://api.themoviedb.org/x')),
          'PROXY 127.0.0.1:7897');
      await r.configure(
          userProxy: '',
          autoTunnel: false,
          forceDirect: false,
          installOverride: false);
      expect(r.proxyFor(Uri.parse('https://api.pexels.com/x')), 'DIRECT');
    });
  });

  group('DoH 解析', () {
    test('JSON 解析 + TTL 缓存 + 并发去重', () async {
      int calls = 0;
      final DohResolver resolver = DohResolver(httpGet: (String url) async {
        calls++;
        expect(url, contains('name=api.example.com'));
        return jsonEncode(<String, Object?>{
          'Status': 0,
          'Answer': <Object?>[
            <String, Object?>{
              'name': 'api.example.com',
              'type': 1,
              'TTL': 120,
              'data': '104.20.17.1'
            },
            <String, Object?>{
              'name': 'api.example.com',
              'type': 5,
              'TTL': 120,
              'data': 'cname.example.'
            },
          ],
        });
      });
      final List<List<String>> results =
          await Future.wait(<Future<List<String>>>[
        resolver.resolve('api.example.com'),
        resolver.resolve('api.example.com'),
      ]);
      expect(results[0], <String>['104.20.17.1']);
      expect(results[1], <String>['104.20.17.1']);
      expect(calls, 1, reason: '并发请求应合并为一次');
      await resolver.resolve('api.example.com');
      expect(calls, 1, reason: 'TTL 内应命中缓存');
      await resolver.dispose();
    });

    test('端点失败自动回退下一个端点', () async {
      final List<String> tried = <String>[];
      final DohResolver resolver = DohResolver(httpGet: (String url) async {
        tried.add(url);
        if (url.contains('doh.pub')) throw const SocketException('blocked');
        return jsonEncode(<String, Object?>{
          'Answer': <Object?>[
            <String, Object?>{'type': 1, 'TTL': 60, 'data': '1.2.3.4'},
          ],
        });
      });
      final List<String> ips = await resolver.resolve('blocked.example.com');
      expect(ips, <String>['1.2.3.4']);
      expect(tried.length, 2);
      expect(tried.first, contains('doh.pub'));
      await resolver.dispose();
    });
  });

  group('CONNECT 隧道', () {
    test('隧道盲转发：CONNECT → 200 → 字节透传', () async {
      // 上游：本地回显服务。
      final ServerSocket upstreamServer =
          await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final int upstreamPort = upstreamServer.port;
      final List<Socket> upstreamClients = <Socket>[];
      upstreamServer.listen((Socket s) {
        upstreamClients.add(s);
        s.listen((List<int> data) => s.add(data));
      });

      // 桩解析器：任何域名解析到本地回显服务。
      final DohResolver stub = DohResolver(
          httpGet: (String url) async => jsonEncode(<String, Object?>{
                'Answer': <Object?>[
                  <String, Object?>{
                    'type': 1,
                    'TTL': 60,
                    'data': '127.0.0.1',
                  },
                ],
              }));
      final NetRouter router = NetRouter.I;
      router.debugSetResolver(stub);
      await router.configure(
          userProxy: '',
          autoTunnel: true,
          forceDirect: false,
          installOverride: false);
      expect(router.tunnelRunning, isTrue, reason: '隧道应已启动');

      // 客户端：经隧道 CONNECT 到本地回显服务。
      final Socket client =
          await Socket.connect(InternetAddress.loopbackIPv4, router.tunnelPort);
      client.write('CONNECT echo.local:$upstreamPort HTTP/1.1\r\n'
          'Host: echo.local:$upstreamPort\r\n\r\n');
      final List<int> buffer = <int>[];
      final Completer<void> connected = Completer<void>();
      final StreamSubscription<List<int>> sub = client.listen((List<int> data) {
        buffer.addAll(data);
        final String text = utf8.decode(buffer, allowMalformed: true);
        if (!connected.isCompleted && text.contains('\r\n\r\n')) {
          connected.complete();
        }
      });
      try {
        await connected.future.timeout(const Duration(seconds: 5));
      } catch (e) {
        fail('隧道未响应：$e\n日志：\n${router.log.join('\n')}');
      }
      final String head = utf8.decode(buffer, allowMalformed: true);
      expect(head, contains('HTTP/1.1 200 Connection Established'));

      // 透传验证：发送 ping 收到 pong（回显）。
      client.write('ping-1234\n');
      final Completer<String> echoed = Completer<String>();
      Timer.periodic(const Duration(milliseconds: 50), (Timer t) {
        final String text = utf8.decode(buffer, allowMalformed: true);
        if (!echoed.isCompleted && text.contains('ping-1234')) {
          echoed.complete(text);
          t.cancel();
        }
      });
      final String text =
          await echoed.future.timeout(const Duration(seconds: 5));
      expect(text, contains('ping-1234'), reason: '隧道应透传字节');

      await sub.cancel();
      client.destroy();
      for (final Socket s in upstreamClients) {
        s.destroy();
      }
      await upstreamServer.close();
      await router.configure(
          userProxy: '',
          autoTunnel: false,
          forceDirect: false,
          installOverride: false);
      await stub.dispose();
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('重试退避', () {
    test('500 两次后成功（重试 2 次，共 3 次请求）', () async {
      int hits = 0;
      final HttpServer server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest req) {
        hits++;
        if (hits < 3) {
          req.response.statusCode = 500;
        } else {
          req.response.statusCode = 200;
          req.response.write('ok');
        }
        req.response.close();
      });
      final NetRouter router = NetRouter.I;
      final dynamic res = await router
          .dio(retries: 2, connectTimeout: const Duration(seconds: 5))
          .get<Object?>('http://127.0.0.1:${server.port}/');
      expect(res.statusCode, 200);
      expect(hits, 3);
      await server.close(force: true);
    });
  });
}
