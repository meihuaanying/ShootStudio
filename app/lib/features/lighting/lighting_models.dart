import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../core/utils/json_utils.dart';

/// 布光场景数据模型（俯视图 ↔ 3D 引擎 ↔ 策划案引用的唯一结构化表示）。
enum LightType {
  hard('硬光'),
  soft('柔光'),
  panel('平板光');

  const LightType(this.label);
  final String label;

  static LightType fromName(String? name) =>
      LightType.values.firstWhere((LightType t) => t.name == name,
          orElse: () => LightType.hard);
}

/// 单个设备/道具实例。
class DeviceSpec {
  DeviceSpec({
    required this.id,
    required this.kind,
    required this.name,
    required this.type,
    this.x = 0,
    this.y = 0,
    this.height = 1.9,
    this.intensity = 70,
    this.kelvin = 5500,
    this.beamAngle = 45,
    this.softness = 0.15,
    this.fixture = 'cob-600d',
    this.modifier = 'bare',
    this.color = '#ffffff',
    this.on = true,
    this.note = '',
    this.rotation = 0,
    this.scale = 1,
    this.texture = '',
    this.stand = 'normal',
    this.offsetYaw = 0,
    this.offsetPitch = 0,
  });

  final String id;
  final String kind; // light | prop
  String name;

  /// light: hard/soft/panel；prop: sofa/umbrella/crate/backdrop/reflector/bouquet。
  String type;
  double x;
  double y;
  double height;
  int intensity;
  int kelvin;
  double beamAngle;
  double softness;
  String fixture;
  String modifier;
  String color;
  bool on;
  String note;
  double rotation;
  double scale;

  /// 道具/灯光的自定义贴图（dataURL，D23：上传图作为贴图占位出现在 3D 场景）。
  String texture;

  /// V6/D105：灯架形式 normal | c | boom。
  String stand;

  /// V6/D109：自动瞄准之上的手动偏移（度）。
  double offsetYaw;
  double offsetPitch;

  bool get isLight => kind == 'light';

  DeviceSpec copy() => DeviceSpec.fromJson(deepCopy(toJson()), id: id);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind,
        'name': name,
        'type': type,
        'x': x,
        'y': y,
        'height': height,
        'intensity': intensity,
        'kelvin': kelvin,
        'beamAngle': beamAngle,
        'softness': softness,
        'fixture': fixture,
        'modifier': modifier,
        'color': color,
        'on': on,
        'note': note,
        'rotation': rotation,
        if (isLight) 'rotationY': rotation,
        'scale': scale,
        if (texture.isNotEmpty) 'texture': texture,
        if (isLight) 'stand': stand,
        if (isLight) 'offsetYaw': offsetYaw,
        if (isLight) 'offsetPitch': offsetPitch,
      };

  static DeviceSpec fromJson(Map<String, Object?> json, {String? id}) =>
      DeviceSpec(
        id: id ?? json['id'] as String? ?? const Uuid().v4(),
        kind: json['kind'] as String? ?? 'light',
        name: json['name'] as String? ?? '设备',
        type: json['type'] as String? ?? 'hard',
        x: asDouble(json['x']),
        y: asDouble(json['y']),
        height: asDouble(json['height'], 1.9),
        intensity: asInt(json['intensity'], 70),
        kelvin: asInt(json['kelvin'], 5500),
        beamAngle: asDouble(json['beamAngle'], 45),
        softness: asDouble(json['softness'], 0.15),
        fixture: json['fixture'] as String? ?? 'cob-600d',
        modifier: json['modifier'] as String? ?? 'bare',
        color: json['color'] as String? ?? '#ffffff',
        on: json['on'] as bool? ?? true,
        note: json['note'] as String? ?? '',
        rotation: asDouble(json['rotation']),
        scale: asDouble(json['scale'], 1),
        texture: json['texture'] as String? ?? '',
        stand: json['stand'] as String? ?? 'normal',
        offsetYaw: asDouble(json['offsetYaw']),
        offsetPitch: asDouble(json['offsetPitch']),
      );
}

/// V6/D105：摄影师机位（三脚架 + 相机），可一键切 POV 看构图。
class CameraRigData {
  CameraRigData({
    this.x = 0,
    this.y = 3.2,
    this.height = 1.35,
    this.yaw = 0,
    this.pitch = 0,
    this.focal = 50,
    this.enabled = true,
  });

  double x;
  double y;
  double height;
  double yaw;
  double pitch;
  int focal;
  bool enabled;

  Map<String, Object?> toJson() => <String, Object?>{
        'x': x,
        'y': y,
        'height': height,
        'yaw': yaw,
        'pitch': pitch,
        'focal': focal,
        'enabled': enabled,
      };

  static CameraRigData fromJson(Map<String, Object?>? json) {
    final Map<String, Object?> j = json ?? <String, Object?>{};
    return CameraRigData(
      x: asDouble(j['x']),
      y: asDouble(j['y'], 3.2),
      height: asDouble(j['height'], 1.35),
      yaw: asDouble(j['yaw']),
      pitch: asDouble(j['pitch']),
      focal: asInt(j['focal'], 50).clamp(14, 200),
      enabled: j['enabled'] as bool? ?? true,
    );
  }

  CameraRigData copy() => CameraRigData.fromJson(deepCopy(toJson()));
}

/// 几何量：方位角（0°=被摄体正面=画布上方，顺时针）与距离（米）。
class DeviceGeometry {
  const DeviceGeometry(this.azimuth, this.distance);
  final double azimuth;
  final double distance;

  String get azimuthLabel => '${azimuth.toStringAsFixed(0)}°';
  String get distanceLabel => '${distance.toStringAsFixed(1)}m';
}

DeviceGeometry geometryOf(double x, double y) {
  var deg = math.atan2(x, -y) * 180 / math.pi;
  if (deg < 0) deg += 360;
  return DeviceGeometry(deg % 360, math.sqrt(x * x + y * y));
}

/// 布光场景。
class LightingSceneData {
  LightingSceneData({
    required this.id,
    required this.name,
    required this.devices,
    this.width = 6,
    this.depth = 8,
    this.height = 3.2,
    this.hands,
    this.ambientEnabled = true,
    CameraRigData? camera,
  }) : camera = camera ?? CameraRigData();

  final String id;
  String name;
  List<DeviceSpec> devices;
  double width;
  double depth;
  double height;

  /// V5/D88：手部姿态（随场景保存/恢复；{l:{...}, r:{...}}）。
  Map<String, Object?>? hands;

  /// V5/D85：环境光开关（随场景保存/恢复）。
  bool ambientEnabled;

  /// V6/D105：摄影师机位（随场景保存/恢复）。
  CameraRigData camera;

  static const int maxDevices = 40;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'width': width,
        'depth': depth,
        'height': height,
        'devices': devices.map((DeviceSpec d) => d.toJson()).toList(),
        if (hands != null && hands!.isNotEmpty) 'hands': hands,
        'ambientEnabled': ambientEnabled,
        'camera': camera.toJson(),
      };

  static LightingSceneData fromJson(Map<String, Object?> json) =>
      LightingSceneData(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String? ?? '未命名布光方案',
        width: asDouble(json['width'], 6),
        depth: asDouble(json['depth'], 8),
        height: asDouble(json['height'], 3.2),
        devices: asMapList(json['devices']).map(DeviceSpec.fromJson).toList(),
        hands: json['hands'] == null ? null : asMap(json['hands']),
        ambientEnabled: json['ambientEnabled'] as bool? ?? true,
        camera: CameraRigData.fromJson(
            json['camera'] == null ? null : asMap(json['camera'])),
      );

  List<DeviceSpec> get lights =>
      devices.where((DeviceSpec d) => d.isLight).toList();
  List<DeviceSpec> get props =>
      devices.where((DeviceSpec d) => !d.isLight).toList();

  /// 转换为 3D 引擎场景 JSON。
  Map<String, Object?> toEngineJson({
    Map<String, Object?>? poseJoints,
    Map<String, Object?>? hands,
    bool showPerson = true,
  }) =>
      <String, Object?>{
        'version': 1,
        'studio': <String, Object?>{
          'width': width,
          'depth': depth,
          'height': height
        },
        'subject': <String, Object?>{
          'height': 1.7,
          'visible': showPerson,
          'rotationY': 0,
          if (poseJoints != null)
            'pose': <String, Object?>{'joints': poseJoints, 'duration': 380},
          if (hands != null && hands.isNotEmpty) 'hands': hands,
        },
        'lights': lights.map((DeviceSpec d) => d.toJson()).toList(),
        'props': props.map((DeviceSpec d) => d.toJson()).toList(),
        // V6/D105：机位随场景同步（引擎侧 setCameraRig 消费）。
        'camera': camera.toJson(),
      };

  LightingSceneData copy() => LightingSceneData.fromJson(
        deepCopy(toJson()),
      );
}

/// 从预设设备列表创建设备实例（分配 id 与名称序号）。
List<DeviceSpec> instantiatePresetDevices(
    List<Map<String, Object?>> presetDevices) {
  const Uuid uuid = Uuid();
  return presetDevices.map((Map<String, Object?> raw) {
    final isProp = raw.containsKey('type') &&
        const <String>[
          'sofa',
          'umbrella',
          'crate',
          'backdrop',
          'reflector',
          'bouquet'
        ].contains(raw['type']);
    if (isProp) {
      return DeviceSpec(
        id: uuid.v4(),
        kind: 'prop',
        name: raw['name'] as String? ?? '道具',
        type: raw['type'] as String? ?? 'crate',
        x: asDouble(raw['x']),
        y: asDouble(raw['y']),
        rotation: asDouble(raw['rotation']),
        scale: asDouble(raw['scale'], 1),
      );
    }
    return DeviceSpec(
      id: uuid.v4(),
      kind: 'light',
      name: raw['name'] as String? ?? '灯光',
      type: raw['type'] as String? ?? 'hard',
      x: asDouble(raw['x']),
      y: asDouble(raw['y']),
      height: asDouble(raw['height'], 1.9),
      intensity: asInt(raw['intensity'], 70),
      kelvin: asInt(raw['kelvin'], 5500),
      beamAngle: asDouble(raw['beamAngle'], 45),
      softness: asDouble(raw['softness'], 0.15),
      fixture: raw['fixture'] as String? ?? 'cob-600d',
      modifier: raw['modifier'] as String? ?? 'bare',
      color: raw['color'] as String? ?? '#ffffff',
      rotation: asDouble(raw['rotationY']),
      note: raw['note'] as String? ?? '',
      stand: raw['stand'] as String? ?? 'normal',
      offsetYaw: asDouble(raw['offsetYaw']),
      offsetPitch: asDouble(raw['offsetPitch']),
    );
  }).toList();
}
