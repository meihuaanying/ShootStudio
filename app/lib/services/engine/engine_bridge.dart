import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/utils/json_utils.dart';

/// 3D 引擎事件（JS → Flutter）。
sealed class EngineEvent {
  const EngineEvent();
}

class EngineReady extends EngineEvent {
  const EngineReady(this.version);
  final int version;
}

class EngineJointClicked extends EngineEvent {
  const EngineJointClicked(this.joint);
  final String joint;
}

class EngineSelection extends EngineEvent {
  const EngineSelection(this.kind, this.id);
  final String? kind;
  final String? id;
}

/// 3D 内拖动灯/道具后的坐标回传（画布坐标 x/y，米）。
class EngineSceneChanged extends EngineEvent {
  const EngineSceneChanged({this.lights, this.props});
  final List<Map<String, Object?>>? lights;
  final List<Map<String, Object?>>? props;
}

/// V3：人物/服装/发型/肤色切换完成（GLB 骨骼模型）。
class EngineCharacterChanged extends EngineEvent {
  const EngineCharacterChanged({
    required this.character,
    required this.name,
    this.hair,
  });
  final String character;
  final String name;
  final String? hair;
}

class EngineCaptured extends EngineEvent {
  const EngineCaptured(this.dataUrl, {this.token = ''});
  final String dataUrl;

  /// V7/D138：定向取图标记（A/B 冻结等）；空 = 普通效果预览保存。
  final String token;
}

/// V7/D138：静帧渲染进度（路径追踪编译/采样阶段）。
class EngineStillProgress extends EngineEvent {
  const EngineStillProgress({
    required this.mode,
    required this.phase,
    required this.samples,
    required this.target,
    required this.elapsedMs,
    this.width = 0,
    this.height = 0,
  });
  final String mode; // path | warm
  final String phase; // compile | render | done
  final int samples;
  final int target;
  final int elapsedMs;
  final int width;
  final int height;
}

/// V7/D138：静帧渲染完成（dataUrl 为 PNG；失败时 ok=false + error）。
class EngineStillRendered extends EngineEvent {
  const EngineStillRendered({
    required this.ok,
    required this.mode,
    required this.dataUrl,
    this.reason = '',
    this.error = '',
    this.width = 0,
    this.height = 0,
    this.samples = 0,
    this.ms = 0,
    this.msPerSample,
    this.dof = false,
    this.fStop = 0,
    this.focusDistance = 0,
    this.focusMode = '',
    this.dofFallback = false,
  });
  final bool ok;
  final String mode; // path | supersample
  final String dataUrl;
  final String reason;
  final String error;
  final int width;
  final int height;
  final int samples;
  final int ms;
  final double? msPerSample;

  /// V7/D139：景深是否生效（仅路径追踪），以及对焦参数。
  final bool dof;
  final double fStop;
  final double focusDistance;
  final String focusMode;

  /// R69：请求了景深但回退到超采样（景深不可用）。
  final bool dofFallback;
}

class EngineErrorEvent extends EngineEvent {
  const EngineErrorEvent(this.message, {this.fatal = false, this.source = ''});
  final String message;

  /// V6/R41：仅致命错误（引擎引导失败/渲染上下文丢失）才允许降级整体面板；
  /// 角色/资源等局部错误 fatal=false，只提示并可重试。
  final bool fatal;
  final String source;
}

/// V6/R43：渲染心跳（每秒一次），Flutter 侧据此判断引擎存活并触发自动重载。
class EngineHeartbeat extends EngineEvent {
  const EngineHeartbeat({
    required this.frames,
    required this.fps,
    this.usedHeapMB,
  });
  final int frames;
  final int fps;
  final double? usedHeapMB;
}

/// V6/R43：WebView 控制台日志（转发到 AppLogger，便于诊断包）。
class EngineConsole extends EngineEvent {
  const EngineConsole({required this.level, required this.message});
  final String level;
  final String message;
}

/// 引擎桥：场景 JSON 双向同步（D5 双轨制轨道一）。
class EngineBridge {
  EngineBridge();

  InAppWebViewController? _controller;
  bool ready = false;
  final StreamController<EngineEvent> _events =
      StreamController<EngineEvent>.broadcast();

  Stream<EngineEvent> get events => _events.stream;

  void attach(InAppWebViewController controller) {
    _controller = controller;
  }

  /// 处理 JS 侧 [window.flutter_inappwebview.callHandler('ssBridge', msg)]。
  void handleMessage(String raw) {
    try {
      final data = asMap(jsonDecode(raw));
      final type = data['type'] as String? ?? '';
      switch (type) {
        case 'ready':
          ready = true;
          _events.add(EngineReady(asInt(data['version'], 1)));
        case 'jointClicked':
          _events.add(EngineJointClicked(data['joint'] as String? ?? ''));
        case 'selection':
          _events.add(
            EngineSelection(data['kind'] as String?, data['id'] as String?),
          );
        case 'sceneChanged':
          _events.add(
            EngineSceneChanged(
              lights: data['lights'] == null ? null : asMapList(data['lights']),
              props: data['props'] == null ? null : asMapList(data['props']),
            ),
          );
        case 'characterChanged':
          _events.add(
            EngineCharacterChanged(
              character: data['character'] as String? ?? '',
              name: data['name'] as String? ?? '',
              hair: data['hair'] as String?,
            ),
          );
        case 'hairChanged':
          // 发型变化并入人物事件流（信息性，UI 可不处理）。
          break;
        case 'captured':
          final dataUrl = data['dataUrl'] as String? ?? '';
          if (dataUrl.isNotEmpty) {
            _events.add(
              EngineCaptured(dataUrl, token: data['token'] as String? ?? ''),
            );
          }
        case 'stillProgress':
          _events.add(
            EngineStillProgress(
              mode: data['mode'] as String? ?? 'path',
              phase: data['phase'] as String? ?? '',
              samples: asInt(data['samples']),
              target: asInt(data['target']),
              elapsedMs: asInt(data['elapsedMs']),
              width: asInt(data['width']),
              height: asInt(data['height']),
            ),
          );
        case 'stillRendered':
          _events.add(
            EngineStillRendered(
              ok: data['ok'] == true,
              mode: data['mode'] as String? ?? 'path',
              dataUrl: data['dataUrl'] as String? ?? '',
              reason: data['reason'] as String? ?? '',
              error: data['error'] as String? ?? '',
              width: asInt(data['width']),
              height: asInt(data['height']),
              samples: asInt(data['samples']),
              ms: asInt(data['ms']),
              msPerSample: (data['msPerSample'] as num?)?.toDouble(),
              dof: data['dof'] == true,
              fStop: (data['fStop'] as num?)?.toDouble() ?? 0,
              focusDistance: (data['focusDistance'] as num?)?.toDouble() ?? 0,
              focusMode: data['focusMode'] as String? ?? '',
              dofFallback: data['dofFallback'] == true,
            ),
          );
        case 'engineHeartbeat':
          _events.add(
            EngineHeartbeat(
              frames: asInt(data['frames']),
              fps: asInt(data['fps']),
              usedHeapMB: (data['memory'] as Map?)?['usedMB'] is num
                  ? ((data['memory'] as Map)['usedMB'] as num).toDouble()
                  : null,
            ),
          );
        case 'engineConsole':
          _events.add(
            EngineConsole(
              level: data['level'] as String? ?? 'log',
              message: data['message'] as String? ?? '',
            ),
          );
        case 'error':
          _events.add(
            EngineErrorEvent(
              data['message'] as String? ?? '未知错误',
              fatal: data['fatal'] == true,
              source: data['source'] as String? ?? '',
            ),
          );
      }
    } catch (_) {
      // 忽略无法解析的消息。
    }
  }

  Future<void> _js(String source) async {
    try {
      await _controller?.evaluateJavascript(source: source);
    } catch (_) {
      // WebView 未就绪时忽略。
    }
  }

  /// V6/D103：求值并取回结果（诊断包读取引擎统计用）。
  Future<Object?> evaluate(String source) async {
    try {
      return await _controller?.evaluateJavascript(source: source);
    } catch (_) {
      return null;
    }
  }

  /// 全量应用场景（灯/道具/假人/影棚）。
  Future<void> applyScene(Map<String, Object?> scene) =>
      _js('window.ss && window.ss.applyScene(${jsonEncode(scene)});');

  /// 平滑切换到姿势（关节角 JSON）。
  Future<void> setPose(Map<String, Object?> joints, {int durationMs = 300}) =>
      _js(
        'window.ss && window.ss.setPose(${jsonEncode(joints)}, $durationMs);',
      );

  Future<void> setJoint(String joint, List<double> rotation) => _js(
    'window.ss && window.ss.setJoint("$joint", ${jsonEncode(rotation)});',
  );

  Future<void> setJointMode(bool on) =>
      _js('window.ss && window.ss.setJointMode(${on ? 'true' : 'false'});');

  Future<void> setView(String mode) =>
      _js('window.ss && window.ss.setView("$mode");');

  Future<void> setGrid(bool on) =>
      _js('window.ss && window.ss.setGrid(${on ? 'true' : 'false'});');

  Future<void> setLinkage(bool on) =>
      _js('window.ss && window.ss.setLinkage(${on ? 'true' : 'false'});');

  Future<void> setTheme(bool dark) =>
      _js('window.ss && window.ss.setTheme("${dark ? 'dark' : 'light'}");');

  /// 隐藏页暂停渲染（F5）。
  Future<void> setPaused(bool paused) =>
      _js('window.ss && window.ss.setPaused(${paused ? 'true' : 'false'});');

  Future<void> setGender(String gender) =>
      _js('window.ss && window.ss.setGender && window.ss.setGender("$gender")');

  Future<void> setSkeletonMode(bool on) => _js(
    'window.ss && window.ss.setSkeletonMode && window.ss.setSkeletonMode(${on ? 'true' : 'false'})',
  );

  /// V4/Q1：细分等级（0 轻量 / 1 标准 / 2 高）。
  Future<void> setSubdivision(int level) => _js(
    'window.ss && window.ss.setSubdivision && window.ss.setSubdivision($level);',
  );

  /// V4/Q1：材质预设（standard | realistic | light）。
  Future<void> setMaterialPreset(String preset) => _js(
    'window.ss && window.ss.setMaterialPreset && window.ss.setMaterialPreset("$preset");',
  );

  /// V4/Q1：环境反射强度（0..2）。
  Future<void> setEnvIntensity(double value) => _js(
    'window.ss && window.ss.setEnvIntensity && window.ss.setEnvIntensity($value);',
  );

  /// V5/D85：环境光开关（关 = 半球光 + 环境贴图贡献全部关闭）。
  Future<void> setAmbientEnabled(bool on) => _js(
    'window.ss && window.ss.setAmbientEnabled && window.ss.setAmbientEnabled(${on ? 'true' : 'false'});',
  );

  /// V5/D91：接触阴影开关（仅 realistic 预设生效）。
  Future<void> setContactShadow(bool on) => _js(
    'window.ss && window.ss.setContactShadow && window.ss.setContactShadow(${on ? 'true' : 'false'});',
  );

  /// V6/D104：性能档（auto | high | low）。
  Future<void> setPerformanceProfile(String profile) => _js(
    'window.ss && window.ss.setPerformanceProfile && window.ss.setPerformanceProfile("$profile");',
  );

  /// V7/D137：软阴影（VSM）开关。
  Future<void> setSoftShadows(bool on) => _js(
    'window.ss && window.ss.setSoftShadows && window.ss.setSoftShadows(${on ? 'true' : 'false'});',
  );

  /// V6/D111：光锥可视化开关。
  Future<void> setLightCones(bool on) => _js(
    'window.ss && window.ss.setLightCones && window.ss.setLightCones(${on ? 'true' : 'false'});',
  );

  /// V6/D105：相机 POV 预览开关。
  Future<void> setCameraView(bool on) => _js(
    'window.ss && window.ss.setCameraView && window.ss.setCameraView(${on ? 'true' : 'false'});',
  );

  /// V6/D105：机位参数（位置/高度/俯仰/偏航/焦段）。
  Future<void> setCameraRig(Map<String, Object?> rig) => _js(
    'window.ss && window.ss.setCameraRig && window.ss.setCameraRig(${jsonEncode(rig)});',
  );

  /// V5/D86：手部预设（side: l|r；双手组合预设会同时写入左右手）。
  Future<void> setHandPose(String side, String presetId) => _js(
    'window.ss && window.ss.setHandPose && window.ss.setHandPose("$side", "$presetId");',
  );

  /// V5/D86：每指微调（curls: {thumb,index,middle,ring,pinky,spread,wrist}）。
  Future<void> setHandCurls(String side, Map<String, Object?> curls) => _js(
    'window.ss && window.ss.setHandCurls && window.ss.setHandCurls("$side", ${jsonEncode(curls)});',
  );

  /// V5/D86：重置手部为自然放松。
  Future<void> resetHands() =>
      _js('window.ss && window.ss.resetHands && window.ss.resetHands();');

  /// V3：切换 GLB 人物（'legacy' 为显式轻量假人）。
  Future<void> setCharacter(String id) => _js(
    'window.ss && window.ss.setCharacter && window.ss.setCharacter("$id")',
  );

  Future<void> setOutfit(String? id) => _js(
    'window.ss && window.ss.setOutfit && window.ss.setOutfit(${id == null ? 'null' : '"$id"'});',
  );

  Future<void> setHair(String? id) => _js(
    'window.ss && window.ss.setHair && window.ss.setHair(${id == null ? 'null' : '"$id"'});',
  );

  Future<void> setSkinTone(String? hex) => _js(
    'window.ss && window.ss.setSkinTone && window.ss.setSkinTone(${hex == null ? 'null' : '"$hex"'});',
  );

  Future<void> setSubjectVisible(bool on) => _js(
    'window.ss && window.ss.setSubjectVisible(${on ? 'true' : 'false'});',
  );

  Future<void> capturePhoto({String token = ''}) => _js(
    'window.ss && window.ss.capturePhoto(${token.isEmpty ? '' : '"$token"'});',
  );

  /// V7/D138：渲染静帧（path 路径追踪 / supersample 超采样）。
  /// [dof]（V7/D139）：`{enabled, fStop, focusMode('auto'|'manual'), focusDistance}`，仅路径追踪生效。
  /// 进度与结果分别通过 [EngineStillProgress] / [EngineStillRendered] 事件回传。
  Future<void> renderStill({
    String mode = 'path',
    int width = 960,
    int height = 720,
    int samples = 128,
    int bounces = 4,
    int factor = 2,
    bool useCameraRig = true,
    Map<String, Object?>? dof,
  }) => _js(
    'window.ss && window.ss.renderStill && window.ss.renderStill(${jsonEncode(<String, Object?>{'mode': mode, 'width': width, 'height': height, 'samples': samples, 'bounces': bounces, 'factor': factor, 'useCameraRig': useCameraRig, if (dof != null) 'dof': dof})});',
  );

  /// V7/D139：焦段/视野/对焦距离辅助信息（含景深可用性）。
  Future<Map<String, Object?>?> getCameraAssist() async {
    final Object? raw = await evaluate(
      'window.ss && window.ss.getCameraAssist ? JSON.stringify(window.ss.getCameraAssist()) : ""',
    );
    if (raw is! String || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, Object?>() : null;
    } catch (_) {
      return null;
    }
  }

  /// V7/D138：后台预热路径追踪器（提前付掉着色器编译成本；失败不影响导出）。
  Future<void> warmPathTracer() => _js(
    'window.ss && window.ss.warmPathTracer && window.ss.warmPathTracer();',
  );

  void dispose() {
    _events.close();
    _controller = null;
  }
}
