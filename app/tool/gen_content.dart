// 内容包生成器：布光预设 / 姿势库 / 策划模板 / 影片索引。
// 运行：dart run tool/gen_content.dart
// 输出：assets/content/**/*.json（确定性；重新运行结果一致）
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

// ---------------- 通用 ----------------
String _hex(num r, num g, num b) =>
    '#${r.round().toRadixString(16).padLeft(2, '0')}'
    '${g.round().toRadixString(16).padLeft(2, '0')}'
    '${b.round().toRadixString(16).padLeft(2, '0')}';

void writeJson(String path, Object data) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  stdout.writeln('written $path');
}

// ---------------- 布光预设 ----------------
Map<String, Object?> _light(
  String name,
  double az,
  double dist,
  double height, {
  String type = 'hard',
  String fixture = 'cob-600d',
  String modifier = 'bare',
  int intensity = 70,
  int kelvin = 5500,
  double beam = 45,
  double softness = 0.15,
  String color = '#ffffff',
  double rotationY = 0,
  String note = '',
}) {
  // 方位角（0°=被摄体正面，顺时针）→ 画布坐标（上方为 -y）。
  final rad = az * math.pi / 180;
  return <String, Object?>{
    'name': name,
    'x': double.parse((math.sin(rad) * dist).toStringAsFixed(3)),
    'y': double.parse((-math.cos(rad) * dist).toStringAsFixed(3)),
    'height': height,
    'type': type,
    'fixture': fixture,
    'modifier': modifier,
    'intensity': intensity,
    'kelvin': kelvin,
    'beamAngle': beam,
    'softness': softness,
    'color': color,
    'rotationY': rotationY,
    'note': note,
  };
}

Map<String, Object?> _prop(String type, double x, double y,
        {double rotation = 0, double scale = 1}) =>
    <String, Object?>{
      'name': <String, String>{
        'sofa': '沙发',
        'umbrella': '透明伞',
        'crate': '箱体',
        'backdrop': '背景布',
        'reflector': '反光板',
        'bouquet': '花束',
      }[type]!,
      'type': type,
      'x': x,
      'y': y,
      'rotation': rotation,
      'scale': scale,
    };

List<Map<String, Object?>> _presets() {
  final list = <Map<String, Object?>>[];

  void add(String id, String name, String category,
      List<Map<String, Object?>> devices, String note) {
    list.add(<String, Object?>{
      'id': id,
      'name': name,
      'category': category,
      'devices': devices,
      'note': note
    });
  }

  add(
      'three-point',
      '三点布光 45°',
      '经典',
      [
        _light('主光 Key', 45, 2.2, 2.0,
            intensity: 75, modifier: 'softbox-medium', beam: 55, softness: 0.4),
        _light('辅光 Fill', 315, 2.6, 1.7,
            intensity: 35, modifier: 'softbox-large', beam: 70, softness: 0.55),
        _light('轮廓光 Rim', 180, 2.8, 2.5,
            type: 'hard', intensity: 80, beam: 30, modifier: 'honeycomb-grid'),
      ],
      'Key 侧前 45°、Fill 对侧、Rim 侧后高位；正片最通用的结构。');

  add(
      'butterfly',
      '蝶形光',
      '经典',
      [
        _light('主光 Key', 0, 2.0, 2.45,
            intensity: 85,
            modifier: 'softbox-medium',
            beam: 50,
            softness: 0.42),
        _light('下反光板', 0, 1.1, 0.55,
            type: 'soft',
            fixture: 'panel-120',
            modifier: 'bare',
            intensity: 25),
      ],
      '主光正前高位，鼻下形成蝶形阴影；非常适合面部骨相与妆造展示。');

  add(
      'rembrandt',
      '伦勃朗光',
      '经典',
      [
        _light('主光 Key', 60, 2.2, 2.2,
            intensity: 75, modifier: 'standard-reflector', beam: 40),
        _light('辅光 Fill', 300, 3.0, 1.5,
            intensity: 22, modifier: 'softbox-large', softness: 0.5),
      ],
      '主光 45–60° 侧上，脸颊三角光斑；低调情绪人像常用。');

  add(
      'split',
      '分割光',
      '经典',
      [
        _light('主光 Key', 90, 2.2, 2.0,
            intensity: 85, modifier: 'standard-reflector', beam: 35),
      ],
      '主光 90° 正侧，半脸受光半脸阴影，戏剧性强。');

  add(
      'loop',
      '环形光',
      '经典',
      [
        _light('主光 Key', 40, 2.4, 2.1,
            intensity: 78, modifier: 'beauty-dish', beam: 48, softness: 0.3),
        _light('反光板', 320, 1.6, 0.8,
            type: 'soft', intensity: 18, modifier: 'bare'),
      ],
      '主光 30–45° 略高于眼位，鼻侧环形阴影，通用好看。');

  add(
      'rim-double',
      '双逆光轮廓',
      '轮廓',
      [
        _light('左轮廓', 200, 2.6, 2.4,
            intensity: 80, beam: 25, modifier: 'snoot', kelvin: 5600),
        _light('右轮廓', 160, 2.6, 2.4,
            intensity: 80, beam: 25, modifier: 'snoot', kelvin: 5600),
        _light('正面柔补', 0, 3.0, 1.8,
            type: 'soft',
            modifier: 'softbox-large',
            intensity: 25,
            softness: 0.6),
      ],
      '双灯勾边 + 轻补面，发光感与分离度极佳（夜景/Cos 常用）。');

  add(
      'dual-soft',
      '双灯柔光',
      '柔光',
      [
        _light('主柔光', 330, 2.8, 2.0,
            type: 'soft',
            modifier: 'softbox-large',
            intensity: 70,
            beam: 75,
            softness: 0.6),
        _light('副柔光', 30, 3.2, 2.0,
            type: 'soft',
            modifier: 'softbox-large',
            intensity: 55,
            beam: 75,
            softness: 0.6),
      ],
      '左右双柔光箱夹光，过渡细腻，适合美妆/妆造。');

  add(
      'hard-contrast',
      '硬光高反差',
      '硬光',
      [
        _light('硬主光', 45, 2.0, 2.6,
            intensity: 90,
            beam: 28,
            modifier: 'honeycomb-grid',
            softness: 0.06),
        _light('轮廓', 200, 2.8, 2.5, intensity: 70, beam: 24, modifier: 'snoot'),
      ],
      '窄束硬光 + 侧后轮廓，边缘锐利、结构感强。');

  add(
      'window-light',
      '窗光模拟',
      '自然',
      [
        _light('窗光', 270, 2.5, 1.7,
            type: 'soft',
            fixture: 'panel-120',
            modifier: 'diffusion-cloth',
            intensity: 65,
            beam: 110,
            softness: 0.65,
            kelvin: 5200),
        _light('反光板', 90, 1.5, 0.9,
            type: 'soft', intensity: 15, modifier: 'bare'),
      ],
      '大面积柔和侧光 + 对侧反光板，室内自然光氛围。');

  add(
      'overcast',
      '阴天平光',
      '自然',
      [
        _light('大面积柔光', 0, 2.6, 2.2,
            type: 'soft',
            fixture: 'panel-120',
            modifier: 'diffusion-cloth',
            intensity: 80,
            beam: 130,
            softness: 0.7),
        _light('天顶补光', 0, 0.4, 3.0,
            type: 'soft',
            fixture: 'panel-120',
            intensity: 40,
            beam: 130,
            softness: 0.7),
      ],
      '无方向性大平光，阴天质感，肤色干净。');

  add(
      'top-drama',
      '顶光戏剧',
      '戏剧',
      [
        _light('顶光', 0, 0.35, 3.0,
            intensity: 88,
            beam: 36,
            modifier: 'honeycomb-grid',
            softness: 0.18),
      ],
      '近顶光位，眼窝阴影重，攻击性/神秘感强。');

  add(
      'side-rim',
      '侧逆光',
      '轮廓',
      [
        _light('侧逆主光', 135, 2.4, 2.3,
            intensity: 82, beam: 30, modifier: 'standard-reflector'),
        _light('正面补光', 315, 2.8, 1.8,
            type: 'soft',
            intensity: 30,
            modifier: 'softbox-large',
            softness: 0.5),
      ],
      '侧后方来光勾出面部轮廓，适合侧脸线条。');

  add(
      'dual-color',
      '双色对撞',
      '氛围',
      [
        _light('暖主光', 45, 2.2, 2.2,
            intensity: 72, kelvin: 3200, modifier: 'standard-reflector'),
        _light('冷轮廓', 225, 2.6, 2.4,
            intensity: 75, kelvin: 7200, beam: 28, modifier: 'snoot'),
      ],
      '暖冷对撞（3200K vs 7200K），赛博/夜景氛围。');

  add(
      'beauty-top',
      '环形顶光',
      '美妆',
      [
        _light('环形光', 0, 1.2, 2.75,
            intensity: 80, beam: 95, modifier: 'beauty-dish', softness: 0.35),
      ],
      '近距高角度环形光，面部饱满，适合妆面展示。');

  add(
      'high-key',
      '高调白',
      '高调',
      [
        _light('左柔光', 345, 3.0, 2.1,
            type: 'soft',
            modifier: 'softbox-large',
            intensity: 75,
            softness: 0.6),
        _light('右柔光', 15, 3.0, 2.1,
            type: 'soft',
            modifier: 'softbox-large',
            intensity: 75,
            softness: 0.6),
        _light('背景光', 180, 2.0, 1.8, intensity: 60, beam: 90),
      ],
      '白底高调：双前柔 + 背景提亮，整体通透。');

  add(
      'low-key',
      '低调黑',
      '低调',
      [
        _light('主光', 30, 2.0, 2.3,
            intensity: 85, beam: 26, modifier: 'snoot', softness: 0.08),
        _light('轮廓', 210, 2.5, 2.5, intensity: 55, beam: 20, modifier: 'snoot'),
      ],
      '窄束低位主光 + 轻微轮廓，黑背景压暗，高级感。');

  add(
      'stage-spot',
      '舞台聚光',
      '戏剧',
      [
        _light('聚光灯', 90, 3.0, 2.6,
            fixture: 'fresnel',
            intensity: 90,
            beam: 22,
            modifier: 'snoot',
            softness: 0.1),
        _light('轻雾补光', 300, 3.2, 1.8,
            type: 'soft', intensity: 20, softness: 0.6),
      ],
      '菲涅尔窄束聚光，舞台追光质感。');

  add(
      'couple',
      '双人站位光',
      '双人',
      [
        _light('人物柔光', 0, 3.0, 2.2,
            type: 'soft',
            modifier: 'softbox-large',
            intensity: 68,
            beam: 90,
            softness: 0.62),
        _light('侧轮廓', 180, 2.8, 2.4, intensity: 60, beam: 45),
      ],
      '宽束前柔 + 后方轮廓，两人同框均受光。');

  add(
      'hanfu-window',
      '汉服窗侧光',
      '古风',
      [
        _light('窗侧主光', 250, 2.6, 2.0,
            type: 'soft',
            fixture: 'panel-120',
            modifier: 'diffusion-cloth',
            intensity: 70,
            beam: 115,
            softness: 0.68,
            kelvin: 5000),
        _light('暖轮廓', 110, 2.8, 2.3,
            intensity: 55, kelvin: 3600, beam: 32, modifier: 'honeycomb-grid'),
      ],
      '大窗柔光 + 暖色轮廓，衣料纹理与褶皱清晰。');

  add(
      'neon-night',
      '夜景霓虹',
      '氛围',
      [
        _light('冷主光', 300, 2.0, 2.2,
            intensity: 68,
            kelvin: 6800,
            modifier: 'softbox-medium',
            softness: 0.45),
        _light('霓虹点缀', 90, 2.2, 1.9,
            intensity: 62,
            color: '#ff4fa3',
            beam: 40,
            modifier: 'standard-reflector'),
        _light('青边光', 190, 2.4, 2.3,
            intensity: 58, color: '#37e6d4', beam: 30, modifier: 'snoot'),
      ],
      '冷主光 + 品红/青色点缀，赛博夜景。');

  add(
      'cos-rim',
      'Cos 逆光轮廓',
      'Cos',
      [
        _light('双色主光', 320, 2.4, 2.1,
            type: 'soft',
            modifier: 'softbox-medium',
            intensity: 70,
            kelvin: 4300,
            softness: 0.45),
        _light('强轮廓', 170, 2.6, 2.5,
            intensity: 85, beam: 26, modifier: 'snoot', kelvin: 6500),
        _light('反光板', 40, 1.6, 0.9,
            type: 'soft', intensity: 16, modifier: 'bare'),
      ],
      '角色正片常见：主光偏暖 + 冷轮廓，服装层次与发丝分离。');

  add(
      'documentary',
      '纪实跟拍光',
      '纪实',
      [
        _light('机顶光', 340, 3.2, 2.4,
            type: 'soft',
            modifier: 'diffusion-cloth',
            intensity: 55,
            beam: 120,
            softness: 0.6),
        _light('环境补光', 200, 3.4, 2.0,
            type: 'soft', intensity: 22, beam: 120, softness: 0.65),
      ],
      '接近纪实跟拍的均匀环境光，适合通勤/JK 外拍补光。');

  add(
      'prop-reflector',
      '主光加反光板',
      '基础',
      [
        _light('主光', 45, 2.2, 2.1,
            intensity: 78, modifier: 'standard-reflector'),
        _prop('reflector', -1.2, 0.9, rotation: 18),
      ],
      '最简布光：单灯 + 反光板补阴影。');

  return list;
}

// ---------------- 姿势库 ----------------
List<Map<String, Object?>> _poses() {
  final poses = <Map<String, Object?>>[];
  var seq = 0;

  Map<String, List<double>> base() => <String, List<double>>{
        'spine': <double>[0, 0, 0],
        'neck': <double>[0, 0, 0],
        'shoulder_l': <double>[0, 0, 8],
        'elbow_l': <double>[-12, 0, 0],
        'wrist_l': <double>[0, 0, 0],
        'shoulder_r': <double>[0, 0, -8],
        'elbow_r': <double>[-12, 0, 0],
        'wrist_r': <double>[0, 0, 0],
        'hip_l': <double>[-2, 0, 2],
        'knee_l': <double>[4, 0, 0],
        'hip_r': <double>[-2, 0, -2],
        'knee_r': <double>[4, 0, 0],
      };

  void add(
    String name,
    String category,
    String difficulty,
    Map<String, List<double>> overrides, {
    double rootY = 0,
    double rootPitch = 0,
    required String weighTip,
    required String handsTip,
    required String mistake,
    required String lens,
  }) {
    seq += 1;
    final joints = base();
    overrides.forEach((key, value) => joints[key] = value);
    poses.add(<String, Object?>{
      'id': 'p${seq.toString().padLeft(3, '0')}',
      'name': name,
      'category': category,
      'difficulty': difficulty,
      'joints': joints,
      'rootY': rootY,
      'rootPitch': rootPitch,
      'weight': weighTip,
      'hands': handsTip,
      'commonMistake': mistake,
      'lens': lens,
    });
  }

  final lensNewbie = '35mm 全身或 50mm 半身，机位与腰齐平';
  final lensAdvanced = '35mm 环境人像，机位略低强化透视';
  final lensHard = '85mm 压缩空间或 24mm 低角度广角，注意畸变';

  // ---- 站姿 15 ----
  add('自然站姿', '站姿', '新手友好', <String, List<double>>{},
      weighTip: '重心居中略偏后，双脚与肩同宽',
      handsTip: '双臂自然下垂，手掌放松',
      mistake: '常见错误：全身绷直显僵硬',
      lens: lensNewbie);
  add(
      '侧身回眸',
      '站姿',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[0, 22, 0],
        'neck': <double>[0, 30, 0],
      },
      weighTip: '重心在后腿，前腿虚点',
      handsTip: '双手自然垂放或轻扶衣摆',
      mistake: '常见错误：脖子扭太狠显用力',
      lens: lensNewbie);
  add(
      '双手插兜',
      '站姿',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[-14, 0, 14],
        'elbow_l': <double>[-72, 0, 18],
        'shoulder_r': <double>[-14, 0, -14],
        'elbow_r': <double>[-72, 0, -18],
      },
      weighTip: '重心偏一侧，胯部微送',
      handsTip: '手自然滑入口袋，肘部放松',
      mistake: '常见错误：耸肩夹肘显紧张',
      lens: lensNewbie);
  add(
      '抱臂而立',
      '站姿',
      '进阶',
      <String, List<double>>{
        'shoulder_l': <double>[6, 0, 34],
        'elbow_l': <double>[-96, 0, 26],
        'shoulder_r': <double>[6, 0, -30],
        'elbow_r': <double>[-92, 0, -30],
        'spine': <double>[0, -6, 0],
      },
      weighTip: '重心后移，肩膀放松下沉',
      handsTip: '双手轻搭对侧手肘，别用力抱紧',
      mistake: '常见错误：抱太紧脸被挡住',
      lens: lensAdvanced);
  add(
      '手扶帽檐',
      '站姿',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[-66, 0, 22],
        'elbow_l': <double>[-104, 0, 0],
        'neck': <double>[6, 0, 0],
      },
      weighTip: '重心居中，下颌微收',
      handsTip: '指尖轻触帽檐，手腕放松',
      mistake: '常见错误：手臂挡住半张脸',
      lens: lensNewbie);
  add(
      '撩发侧望',
      '站姿',
      '进阶',
      <String, List<double>>{
        'shoulder_l': <double>[-108, 0, 30],
        'elbow_l': <double>[-116, 0, 0],
        'neck': <double>[-4, 12, 0],
      },
      weighTip: '上身微侧，胯部反向偏移',
      handsTip: '手从耳后插入发丝，指尖放松',
      mistake: '常见错误：手肘抬得比头顶高',
      lens: lensAdvanced);
  add(
      '单手叉腰',
      '站姿',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[0, 0, 52],
        'elbow_l': <double>[-88, 0, -76],
      },
      weighTip: '叉腰侧胯部顶出，形成曲线',
      handsTip: '四指朝前虎口卡腰',
      mistake: '常见错误：肘部前顶挡视线',
      lens: lensNewbie);
  add(
      '双手背身',
      '站姿',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[18, 0, -24],
        'elbow_l': <double>[-38, 0, -18],
        'shoulder_r': <double>[18, 0, 24],
        'elbow_r': <double>[-38, 0, 18],
      },
      weighTip: '挺胸拔背，下巴微抬',
      handsTip: '双手背后交握',
      mistake: '常见错误：肩向前含胸',
      lens: lensNewbie);
  add(
      '抬手遮阳',
      '站姿',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[-48, 0, 58],
        'elbow_l': <double>[-34, 0, 0],
        'neck': <double>[6, -6, 0],
      },
      weighTip: '重心后仰一点',
      handsTip: '手掌平放额前，四指并拢',
      mistake: '常见错误：手掌贴上额头',
      lens: lensNewbie);
  add(
      '双手合十',
      '站姿',
      '进阶',
      <String, List<double>>{
        'shoulder_l': <double>[-24, 0, 42],
        'elbow_l': <double>[-88, 0, -30],
        'shoulder_r': <double>[-24, 0, -42],
        'elbow_r': <double>[-88, 0, 30],
      },
      weighTip: '重心居中，气息下沉',
      handsTip: '掌根相抵，指尖朝上',
      mistake: '常见错误：肘部外翻太多',
      lens: lensAdvanced);
  add(
      '拉衣领',
      '站姿',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[-18, 0, -30],
        'elbow_l': <double>[-102, 0, -18],
        'neck': <double>[4, 0, 0],
      },
      weighTip: '肩线一高一低更自然',
      handsTip: '拇指食指捏领口，其余放松',
      mistake: '常见错误：手指抓出褶皱',
      lens: lensNewbie);
  add(
      '比心手势',
      '站姿',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[-32, 0, 34],
        'elbow_l': <double>[-102, 0, -56],
        'wrist_l': <double>[0, 0, 24],
        'neck': <double>[0, 0, -6],
      },
      weighTip: '身体微微前倾',
      handsTip: '拇指食指交叉，其余三指并拢',
      mistake: '常见错误：手掌朝向镜头',
      lens: lensNewbie);
  add(
      '撑墙侧身',
      '站姿',
      '进阶',
      <String, List<double>>{
        'shoulder_l': <double>[-8, 0, 66],
        'elbow_l': <double>[-28, 0, 0],
        'spine': <double>[0, 14, -4],
      },
      weighTip: '一手撑墙，重心靠向墙面',
      handsTip: '掌根抵墙，手指自然张开',
      mistake: '常见错误：肩膀顶到耳朵',
      lens: lensAdvanced);
  add(
      '撩裙摆',
      '站姿',
      '进阶',
      <String, List<double>>{
        'shoulder_l': <double>[-22, 0, 24],
        'elbow_l': <double>[-96, 0, -12],
        'shoulder_r': <double>[-22, 0, -24],
        'elbow_r': <double>[-96, 0, 12],
      },
      weighTip: '重心后移，裙摆向前扬',
      handsTip: '指尖捏裙边，手腕内扣',
      mistake: '常见错误：手臂伸直显僵硬',
      lens: lensAdvanced);
  add(
      '正身凝视',
      '站姿',
      '高难度',
      <String, List<double>>{
        'spine': <double>[-2, 0, 0],
        'neck': <double>[-4, 0, 0],
      },
      weighTip: '全程核心收紧，重心稳定',
      handsTip: '双手轻贴大腿外侧',
      mistake: '常见错误：眼神游移没有焦点',
      lens: lensHard);

  // ---- 坐姿 15 ----
  final sitHipL = <double>[-88, 0, 4];
  final sitHipR = <double>[-88, 0, -4];
  final sitKneeL = <double>[86, 0, 0];
  final sitKneeR = <double>[86, 0, 0];
  add(
      '椅上正坐',
      '坐姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': sitHipL,
        'hip_r': sitHipR,
        'knee_l': sitKneeL,
        'knee_r': sitKneeR,
      },
      rootY: -0.42,
      weighTip: '坐骨压实坐面前沿',
      handsTip: '双手交叠搭在膝上',
      mistake: '常见错误：整个人陷进椅子',
      lens: lensNewbie);
  add(
      '侧坐回头',
      '坐姿',
      '进阶',
      <String, List<double>>{
        'hip_l': sitHipL,
        'hip_r': sitHipR,
        'knee_l': sitKneeL,
        'knee_r': sitKneeR,
        'spine': <double>[0, 24, 0],
        'neck': <double>[0, 32, 0],
      },
      rootY: -0.42,
      weighTip: '上半身向椅背方向拧转',
      handsTip: '一只手扶椅背',
      mistake: '常见错误：只转头不转肩',
      lens: lensAdvanced);
  add(
      '抱膝而坐',
      '坐姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-104, 0, 6],
        'hip_r': <double>[-104, 0, -6],
        'knee_l': <double>[116, 0, 0],
        'knee_r': <double>[116, 0, 0],
        'shoulder_l': <double>[-42, 0, 10],
        'elbow_l': <double>[-118, 0, -20],
        'shoulder_r': <double>[-42, 0, -10],
        'elbow_r': <double>[-118, 0, 20],
        'spine': <double>[-8, 0, 0],
        'neck': <double>[8, 0, 0],
      },
      rootY: -0.78,
      weighTip: '蜷成稳定的三角',
      handsTip: '双手环抱膝盖',
      mistake: '常见错误：含胸太深看不见脸',
      lens: lensAdvanced);
  add(
      '台阶斜坐',
      '坐姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-70, 0, 8],
        'hip_r': <double>[-96, 0, -6],
        'knee_l': <double>[72, 0, 0],
        'knee_r': <double>[92, 0, 0],
        'spine': <double>[0, -14, 6],
      },
      rootY: -0.5,
      weighTip: '一侧髋部高一侧低',
      handsTip: '双手撑在身侧台阶',
      mistake: '常见错误：身体歪到失衡',
      lens: lensAdvanced);
  add(
      '盘腿而坐',
      '坐姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-84, 0, 26],
        'hip_r': <double>[-84, 0, -26],
        'knee_l': <double>[96, 0, 0],
        'knee_r': <double>[96, 0, 0],
      },
      rootY: -0.66,
      weighTip: '两侧坐骨均匀受力',
      handsTip: '双手搭在膝头',
      mistake: '常见错误：驼背',
      lens: lensNewbie);
  add(
      '窗台侧坐',
      '坐姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-92, 0, 4],
        'hip_r': <double>[-88, 0, -4],
        'knee_l': <double>[10, 0, 0],
        'knee_r': <double>[88, 0, 0],
        'shoulder_l': <double>[-10, 0, 30],
        'elbow_l': <double>[-36, 0, 0],
      },
      rootY: -0.5,
      weighTip: '一条腿垂下一条腿屈膝',
      handsTip: '一手轻扶窗框',
      mistake: '常见错误：悬空腿绷直',
      lens: lensAdvanced);
  add(
      '沙发半躺',
      '坐姿',
      '高难度',
      <String, List<double>>{
        'hip_l': <double>[-70, 0, 10],
        'hip_r': <double>[-70, 0, -10],
        'knee_l': <double>[64, 0, 0],
        'knee_r': <double>[64, 0, 0],
        'spine': <double>[-24, 0, 0],
        'neck': <double>[16, 0, 0],
        'shoulder_l': <double>[-24, 0, 40],
        'elbow_l': <double>[-96, 0, -40],
      },
      rootY: -0.46,
      weighTip: '腰背贴合沙发靠背',
      handsTip: '单手支头或搭扶手',
      mistake: '常见错误：脖子后仰过度',
      lens: lensHard);
  add(
      '地毯侧坐',
      '坐姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-88, 0, 18],
        'hip_r': <double>[-88, 0, -30],
        'knee_l': <double>[60, 0, 0],
        'knee_r': <double>[110, 0, 0],
        'spine': <double>[0, 10, 0],
      },
      rootY: -0.7,
      weighTip: '重心偏向一侧手臂',
      handsTip: '一只手撑地',
      mistake: '常见错误：手腕折角过大',
      lens: lensNewbie);
  add(
      '椅背反坐',
      '坐姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-92, 0, 6],
        'hip_r': <double>[-92, 0, -6],
        'knee_l': <double>[90, 0, 0],
        'knee_r': <double>[90, 0, 0],
        'shoulder_l': <double>[10, 0, 40],
        'elbow_l': <double>[-92, 0, -20],
        'shoulder_r': <double>[10, 0, -40],
        'elbow_r': <double>[-92, 0, 20],
        'spine': <double>[-6, 0, 0],
      },
      rootY: -0.42,
      weighTip: '胸口靠椅背，重心前倾',
      handsTip: '双臂搭在椅背上',
      mistake: '常见错误：椅子前脚翘起',
      lens: lensAdvanced);
  add(
      '屈膝托腮',
      '坐姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-96, 0, 6],
        'hip_r': <double>[-96, 0, -6],
        'knee_l': <double>[112, 0, 0],
        'knee_r': <double>[112, 0, 0],
        'shoulder_r': <double>[-70, 0, -16],
        'elbow_r': <double>[-120, 0, 16],
        'spine': <double>[-6, 0, 0],
        'neck': <double>[8, 4, 0],
      },
      rootY: -0.6,
      weighTip: '手肘撑在膝盖上形成支点',
      handsTip: '手掌托住下颌',
      mistake: '常见错误：压脸变形',
      lens: lensNewbie);
  add(
      '长椅舒展',
      '坐姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-90, 0, 20],
        'hip_r': <double>[-90, 0, -20],
        'knee_l': <double>[80, 0, 0],
        'knee_r': <double>[80, 0, 0],
        'shoulder_l': <double>[-30, 0, 60],
        'elbow_l': <double>[-40, 0, 0],
        'shoulder_r': <double>[-30, 0, -60],
        'elbow_r': <double>[-40, 0, 0],
        'spine': <double>[4, 0, 0],
      },
      rootY: -0.42,
      weighTip: '双腿张开与肩同宽',
      handsTip: '双手后撑椅面',
      mistake: '常见错误：耸肩缩脖',
      lens: lensAdvanced);
  add(
      '床边垂腿',
      '坐姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-88, 0, 4],
        'hip_r': <double>[-88, 0, -4],
        'knee_l': <double>[6, 0, 0],
        'knee_r': <double>[6, 0, 0],
        'spine': <double>[0, 8, 0],
      },
      rootY: -0.44,
      weighTip: '小腿自然垂下',
      handsTip: '双手撑在身侧',
      mistake: '常见错误：脚尖外八太多',
      lens: lensNewbie);
  add(
      '书桌伏案',
      '坐姿',
      '进阶',
      <String, List<double>>{
        'hip_l': sitHipL,
        'hip_r': sitHipR,
        'knee_l': sitKneeL,
        'knee_r': sitKneeR,
        'spine': <double>[-22, 0, 0],
        'neck': <double>[14, -6, 0],
        'shoulder_l': <double>[-40, 0, 30],
        'elbow_l': <double>[-96, 0, -30],
        'shoulder_r': <double>[-40, 0, -30],
        'elbow_r': <double>[-96, 0, 30],
      },
      rootY: -0.42,
      weighTip: '上半身前倾伏在桌面',
      handsTip: '手掌交叠垫在下巴下',
      mistake: '常见错误：头埋太低压住脸',
      lens: lensAdvanced);
  add(
      '高凳单脚点地',
      '坐姿',
      '高难度',
      <String, List<double>>{
        'hip_l': <double>[-80, 0, 6],
        'hip_r': <double>[-80, 0, -6],
        'knee_l': <double>[86, 0, 0],
        'knee_r': <double>[40, 0, 0],
        'spine': <double>[0, -12, 0],
      },
      rootY: -0.34,
      weighTip: '一条腿踩凳撑一条腿点地',
      handsTip: '一只手扶凳沿',
      mistake: '常见错误：重心不稳晃动',
      lens: lensHard);
  add(
      '席地抱膝',
      '坐姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-108, 0, 8],
        'hip_r': <double>[-108, 0, -8],
        'knee_l': <double>[120, 0, 0],
        'knee_r': <double>[120, 0, 0],
        'shoulder_l': <double>[-46, 0, 12],
        'elbow_l': <double>[-116, 0, -16],
        'shoulder_r': <double>[-46, 0, -12],
        'elbow_r': <double>[-116, 0, 16],
        'spine': <double>[-6, 0, 0],
        'neck': <double>[6, 6, 0],
      },
      rootY: -0.8,
      weighTip: '身体蜷成柔软的一团',
      handsTip: '双手环抱小腿',
      mistake: '常见错误：双脚离地不稳',
      lens: lensNewbie);

  // ---- 跪姿 15 ----
  add(
      '单膝跪地',
      '跪姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-88, 0, 6],
        'knee_l': <double>[116, 0, 0],
        'hip_r': <double>[-30, 0, -6],
        'knee_r': <double>[98, 0, 0],
        'spine': <double>[-8, 0, 0],
      },
      rootY: -0.5,
      weighTip: '后膝触地，前脚踩实',
      handsTip: '单手撑前膝',
      mistake: '常见错误：后膝盖受力过重',
      lens: lensAdvanced);
  add(
      '双膝跪坐',
      '跪姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-8, 0, 6],
        'knee_l': <double>[118, 0, 0],
        'hip_r': <double>[-8, 0, -6],
        'knee_r': <double>[118, 0, 0],
        'spine': <double>[0, 0, 0],
      },
      rootY: -0.62,
      weighTip: '坐于脚跟，脊背立直',
      handsTip: '双手轻放膝上',
      mistake: '常见错误：驼背塌腰',
      lens: lensNewbie);
  add(
      '跪地回眸',
      '跪姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-10, 0, 6],
        'knee_l': <double>[118, 0, 0],
        'hip_r': <double>[-10, 0, -6],
        'knee_r': <double>[118, 0, 0],
        'spine': <double>[0, 26, 0],
        'neck': <double>[0, 34, 0],
      },
      rootY: -0.62,
      weighTip: '腰腹拧转带动上身',
      handsTip: '指尖轻撑地面',
      mistake: '常见错误：转腰过猛',
      lens: lensAdvanced);
  add(
      '武士蹲',
      '跪姿',
      '高难度',
      <String, List<double>>{
        'hip_l': <double>[-96, 0, 12],
        'knee_l': <double>[118, 0, 0],
        'hip_r': <double>[-96, 0, -12],
        'knee_r': <double>[118, 0, 0],
        'spine': <double>[-10, 0, 0],
        'neck': <double>[-6, 0, 0],
        'shoulder_l': <double>[8, 0, 44],
        'elbow_l': <double>[-96, 0, -34],
        'shoulder_r': <double>[8, 0, -44],
        'elbow_r': <double>[-96, 0, 34],
      },
      rootY: -0.72,
      weighTip: '重心压低到两腿之间',
      handsTip: '双手扶膝，目视前方',
      mistake: '常见错误：膝盖内扣',
      lens: lensHard);
  add(
      '跪地仰望',
      '跪姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-6, 0, 6],
        'knee_l': <double>[118, 0, 0],
        'hip_r': <double>[-6, 0, -6],
        'knee_r': <double>[118, 0, 0],
        'spine': <double>[8, 0, 0],
        'neck': <double>[-14, 0, 0],
      },
      rootY: -0.62,
      weighTip: '上身向后舒展',
      handsTip: '双手在身后交握',
      mistake: '常见错误：后仰过度失衡',
      lens: lensAdvanced);
  add(
      '跪姿献花',
      '跪姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-88, 0, 6],
        'knee_l': <double>[116, 0, 0],
        'hip_r': <double>[-14, 0, -6],
        'knee_r': <double>[118, 0, 0],
        'shoulder_l': <double>[-56, 0, 16],
        'elbow_l': <double>[-38, 0, 0],
        'neck': <double>[6, 0, 0],
      },
      rootY: -0.56,
      weighTip: '单膝跪 + 上身递出',
      handsTip: '双手捧花向前递',
      mistake: '常见错误：花挡住脸',
      lens: lensHard);
  add(
      '伏地撑地',
      '跪姿',
      '高难度',
      <String, List<double>>{
        'hip_l': <double>[-84, 0, 8],
        'knee_l': <double>[112, 0, 0],
        'hip_r': <double>[-84, 0, -8],
        'knee_r': <double>[112, 0, 0],
        'spine': <double>[-20, 0, 0],
        'neck': <double>[16, 0, 0],
        'shoulder_l': <double>[-52, 0, 30],
        'elbow_l': <double>[-30, 0, 0],
        'shoulder_r': <double>[-52, 0, -30],
        'elbow_r': <double>[-30, 0, 0],
      },
      rootY: -0.66,
      weighTip: '双手与双膝四点支撑',
      handsTip: '指尖张开抓地',
      mistake: '常见错误：手腕塌陷',
      lens: lensHard);
  add(
      '跪坐抚琴',
      '跪姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-10, 0, 6],
        'knee_l': <double>[118, 0, 0],
        'hip_r': <double>[-10, 0, -6],
        'knee_r': <double>[118, 0, 0],
        'shoulder_l': <double>[-30, 0, 26],
        'elbow_l': <double>[-52, 0, -10],
        'shoulder_r': <double>[-30, 0, -26],
        'elbow_r': <double>[-52, 0, 10],
        'spine': <double>[-10, 0, 0],
        'neck': <double>[10, 0, 0],
      },
      rootY: -0.62,
      weighTip: '端正坐姿配合手部动作',
      handsTip: '双手悬于膝前模拟抚弦',
      mistake: '常见错误：手上动作虚浮',
      lens: lensAdvanced);
  add(
      '低身逗猫',
      '跪姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-70, 0, 10],
        'knee_l': <double>[110, 0, 0],
        'hip_r': <double>[-70, 0, -10],
        'knee_r': <double>[110, 0, 0],
        'spine': <double>[-14, 0, 0],
        'shoulder_r': <double>[-34, 0, -20],
        'elbow_r': <double>[-48, 0, 0],
        'neck': <double>[12, -8, 0],
      },
      rootY: -0.58,
      weighTip: '身体前倾但保持平衡',
      handsTip: '一手向前伸出逗弄',
      mistake: '常见错误：撅臀',
      lens: lensNewbie);
  add(
      '跪姿比心',
      '跪姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-10, 0, 6],
        'knee_l': <double>[118, 0, 0],
        'hip_r': <double>[-10, 0, -6],
        'knee_r': <double>[118, 0, 0],
        'shoulder_l': <double>[-32, 0, 34],
        'elbow_l': <double>[-102, 0, -56],
        'neck': <double>[0, 0, -4],
      },
      rootY: -0.62,
      weighTip: '跪坐稳定，上身微前倾',
      handsTip: '双手在脸侧比心',
      mistake: '常见错误：手挡镜头视线',
      lens: lensNewbie);
  add(
      '跪地遮脸',
      '跪姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-8, 0, 6],
        'knee_l': <double>[118, 0, 0],
        'hip_r': <double>[-8, 0, -6],
        'knee_r': <double>[118, 0, 0],
        'shoulder_l': <double>[-70, 0, 6],
        'elbow_l': <double>[-118, 0, -16],
        'shoulder_r': <double>[-70, 0, -6],
        'elbow_r': <double>[-118, 0, 16],
        'spine': <double>[-8, 0, 0],
      },
      rootY: -0.62,
      weighTip: '含胸蜷缩保住情绪',
      handsTip: '双手虚掩面部留出指缝',
      mistake: '常见错误：真的把脸全挡住',
      lens: lensAdvanced);
  add(
      '单膝点地',
      '跪姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-84, 0, 6],
        'knee_l': <double>[112, 0, 0],
        'hip_r': <double>[-18, 0, -6],
        'knee_r': <double>[102, 0, 0],
        'spine': <double>[-4, 0, 0],
      },
      rootY: -0.5,
      weighTip: '重心放在前脚，后膝轻触地',
      handsTip: '双手叠放前膝',
      mistake: '常见错误：身体前扑',
      lens: lensNewbie);
  add(
      '跪姿侧影',
      '跪姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-10, 0, 6],
        'knee_l': <double>[118, 0, 0],
        'hip_r': <double>[-10, 0, -6],
        'knee_r': <double>[118, 0, 0],
        'spine': <double>[0, 30, 0],
        'neck': <double>[0, 20, 0],
      },
      rootY: -0.62,
      weighTip: '侧向镜头展示轮廓',
      handsTip: '双手自然置于腿侧',
      mistake: '常见错误：身体僵硬',
      lens: lensAdvanced);
  add(
      '跪地爬行',
      '跪姿',
      '高难度',
      <String, List<double>>{
        'hip_l': <double>[-80, 0, 9],
        'knee_l': <double>[108, 0, 0],
        'hip_r': <double>[-80, 0, -9],
        'knee_r': <double>[108, 0, 0],
        'spine': <double>[-16, 0, 0],
        'shoulder_l': <double>[-62, 0, 24],
        'elbow_l': <double>[-20, 0, 0],
        'shoulder_r': <double>[-62, 0, -24],
        'elbow_r': <double>[-58, 0, 0],
        'neck': <double>[-8, 0, 0],
      },
      rootY: -0.6,
      weighTip: '爬行姿态，重心前移',
      handsTip: '双手交替向前',
      mistake: '常见错误：腰部下塌',
      lens: lensHard);
  add(
      '抱膝跪坐',
      '跪姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-16, 0, 8],
        'knee_l': <double>[120, 0, 0],
        'hip_r': <double>[-16, 0, -8],
        'knee_r': <double>[120, 0, 0],
        'shoulder_l': <double>[-40, 0, 10],
        'elbow_l': <double>[-112, 0, -14],
        'shoulder_r': <double>[-40, 0, -10],
        'elbow_r': <double>[-112, 0, 14],
        'spine': <double>[-12, 0, 0],
      },
      rootY: -0.66,
      weighTip: '蜷缩成一团，重心低',
      handsTip: '双手环抱小腿',
      mistake: '常见错误：双臂夹太紧',
      lens: lensNewbie);
  add(
      '跪地伸展',
      '跪姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-10, 0, 6],
        'knee_l': <double>[118, 0, 0],
        'hip_r': <double>[-10, 0, -6],
        'knee_r': <double>[118, 0, 0],
        'shoulder_l': <double>[-120, 0, 40],
        'elbow_l': <double>[-16, 0, 0],
        'shoulder_r': <double>[-120, 0, -40],
        'elbow_r': <double>[-16, 0, 0],
        'spine': <double>[6, 0, 0],
      },
      rootY: -0.62,
      weighTip: '上身向上舒展',
      handsTip: '双臂向上延伸',
      mistake: '常见错误：肋骨外翻',
      lens: lensAdvanced);

  // ---- 蹲姿 15 ----
  final squatRoot = -0.5;
  add(
      '自然蹲姿',
      '蹲姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-92, 0, 10],
        'knee_l': <double>[104, 0, 0],
        'hip_r': <double>[-92, 0, -10],
        'knee_r': <double>[104, 0, 0],
        'spine': <double>[-8, 0, 0],
      },
      rootY: squatRoot,
      weighTip: '重心落在两脚掌之间',
      handsTip: '双手自然搭膝',
      mistake: '常见错误：脚跟离地',
      lens: lensNewbie);
  add(
      '蹲身系带',
      '蹲姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-96, 0, 10],
        'knee_l': <double>[106, 0, 0],
        'hip_r': <double>[-96, 0, -10],
        'knee_r': <double>[106, 0, 0],
        'spine': <double>[-18, 0, 0],
        'shoulder_l': <double>[-34, 0, 8],
        'elbow_l': <double>[-64, 0, -6],
        'shoulder_r': <double>[-34, 0, -8],
        'elbow_r': <double>[-64, 0, 6],
        'neck': <double>[14, 0, 0],
      },
      rootY: squatRoot - 0.04,
      weighTip: '身体前倾够到脚面',
      handsTip: '双手在脚踝处系带',
      mistake: '常见错误：脖子后仰',
      lens: lensNewbie);
  add(
      '蹲姿比心',
      '蹲姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-92, 0, 10],
        'knee_l': <double>[104, 0, 0],
        'hip_r': <double>[-92, 0, -10],
        'knee_r': <double>[104, 0, 0],
        'shoulder_l': <double>[-28, 0, 36],
        'elbow_l': <double>[-96, 0, -50],
        'neck': <double>[0, 0, -4],
      },
      rootY: squatRoot,
      weighTip: '蹲稳后上身微前倾',
      handsTip: '双手在脸侧比心',
      mistake: '常见错误：蹲不稳前扑',
      lens: lensNewbie);
  add(
      '单膝蹲跪',
      '蹲姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-96, 0, 12],
        'knee_l': <double>[110, 0, 0],
        'hip_r': <double>[-24, 0, -8],
        'knee_r': <double>[100, 0, 0],
        'spine': <double>[-6, 0, 0],
      },
      rootY: squatRoot + 0.04,
      weighTip: '一膝下沉一腿支撑',
      handsTip: '单手撑在支撑腿膝盖',
      mistake: '常见错误：膝盖内扣',
      lens: lensAdvanced);
  add(
      '深蹲张望',
      '蹲姿',
      '高难度',
      <String, List<double>>{
        'hip_l': <double>[-104, 0, 12],
        'knee_l': <double>[112, 0, 0],
        'hip_r': <double>[-104, 0, -12],
        'knee_r': <double>[112, 0, 0],
        'spine': <double>[-10, 12, 0],
        'neck': <double>[-4, 16, 0],
      },
      rootY: squatRoot - 0.06,
      weighTip: '全蹲保持平衡',
      handsTip: '双手搭膝，指尖朝前',
      mistake: '常见错误：整个人后倒',
      lens: lensHard);
  add(
      '蹲姿抱膝',
      '蹲姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-100, 0, 10],
        'knee_l': <double>[108, 0, 0],
        'hip_r': <double>[-100, 0, -10],
        'knee_r': <double>[108, 0, 0],
        'shoulder_l': <double>[-46, 0, 8],
        'elbow_l': <double>[-114, 0, -14],
        'shoulder_r': <double>[-46, 0, -8],
        'elbow_r': <double>[-114, 0, 14],
        'spine': <double>[-14, 0, 0],
      },
      rootY: squatRoot - 0.08,
      weighTip: '把重心收进身体中线',
      handsTip: '双手抱膝内侧',
      mistake: '常见错误：脚尖外翻过度',
      lens: lensNewbie);
  add(
      '蹲姿遮脸',
      '蹲姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-94, 0, 10],
        'knee_l': <double>[106, 0, 0],
        'hip_r': <double>[-94, 0, -10],
        'knee_r': <double>[106, 0, 0],
        'shoulder_l': <double>[-70, 0, 8],
        'elbow_l': <double>[-118, 0, -14],
        'shoulder_r': <double>[-70, 0, -8],
        'elbow_r': <double>[-118, 0, 14],
        'spine': <double>[-10, 0, 0],
      },
      rootY: squatRoot - 0.04,
      weighTip: '含胸低头藏住情绪',
      handsTip: '双手虚掩面部',
      mistake: '常见错误：手肘夹住脸',
      lens: lensAdvanced);
  add(
      '下蹲整理',
      '蹲姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-90, 0, 10],
        'knee_l': <double>[102, 0, 0],
        'hip_r': <double>[-90, 0, -10],
        'knee_r': <double>[102, 0, 0],
        'shoulder_l': <double>[-18, 0, 6],
        'elbow_l': <double>[-96, 0, -10],
        'neck': <double>[8, 4, 0],
      },
      rootY: squatRoot,
      weighTip: '蹲身双手整理鞋袜',
      handsTip: '一只手撑膝一只手整理',
      mistake: '常见错误：重心后仰',
      lens: lensNewbie);
  add(
      '蹲姿仰望',
      '蹲姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-96, 0, 10],
        'knee_l': <double>[108, 0, 0],
        'hip_r': <double>[-96, 0, -10],
        'knee_r': <double>[108, 0, 0],
        'spine': <double>[4, 0, 0],
        'neck': <double>[-18, 0, 0],
      },
      rootY: squatRoot - 0.04,
      weighTip: '蹲姿中上身向上延展',
      handsTip: '双手自然垂落膝侧',
      mistake: '常见错误：后仰失衡',
      lens: lensAdvanced);
  add(
      '半蹲蓄力',
      '蹲姿',
      '高难度',
      <String, List<double>>{
        'hip_l': <double>[-82, 0, 10],
        'knee_l': <double>[96, 0, 0],
        'hip_r': <double>[-82, 0, -10],
        'knee_r': <double>[96, 0, 0],
        'spine': <double>[-14, 0, 0],
        'shoulder_l': <double>[-40, 0, 20],
        'elbow_l': <double>[-70, 0, -10],
        'shoulder_r': <double>[-40, 0, -20],
        'elbow_r': <double>[-70, 0, 10],
      },
      rootY: squatRoot + 0.16,
      weighTip: '双腿蓄力准备起跳',
      handsTip: '双拳收在体侧',
      mistake: '常见错误：膝盖超过脚尖',
      lens: lensHard);
  add(
      '蹲地捧花',
      '蹲姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-94, 0, 10],
        'knee_l': <double>[106, 0, 0],
        'hip_r': <double>[-94, 0, -10],
        'knee_r': <double>[106, 0, 0],
        'shoulder_l': <double>[-54, 0, 20],
        'elbow_l': <double>[-54, 0, 0],
        'shoulder_r': <double>[-54, 0, -20],
        'elbow_r': <double>[-54, 0, 0],
        'neck': <double>[6, 0, 0],
      },
      rootY: squatRoot,
      weighTip: '双手捧花在身前',
      handsTip: '花束贴近胸口',
      mistake: '常见错误：花挡住半张脸',
      lens: lensNewbie);
  add(
      '弓步下蹲',
      '蹲姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-86, 0, 14],
        'knee_l': <double>[100, 0, 0],
        'hip_r': <double>[-34, 0, -8],
        'knee_r': <double>[74, 0, 0],
        'spine': <double>[-8, 0, 0],
      },
      rootY: squatRoot + 0.1,
      weighTip: '前腿弓后腿蹬',
      handsTip: '单手扶前膝',
      mistake: '常见错误：后脚跟抬起',
      lens: lensAdvanced);
  add(
      '蹲姿回头',
      '蹲姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-92, 0, 10],
        'knee_l': <double>[104, 0, 0],
        'hip_r': <double>[-92, 0, -10],
        'knee_r': <double>[104, 0, 0],
        'spine': <double>[0, 22, 0],
        'neck': <double>[0, 30, 0],
      },
      rootY: squatRoot,
      weighTip: '蹲姿中腰背拧转',
      handsTip: '双手搭膝放松',
      mistake: '常见错误：只转头不转腰',
      lens: lensNewbie);
  add(
      '蹲坐抱膝',
      '蹲姿',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-104, 0, 12],
        'knee_l': <double>[112, 0, 0],
        'hip_r': <double>[-104, 0, -12],
        'knee_r': <double>[112, 0, 0],
        'shoulder_l': <double>[-48, 0, 10],
        'elbow_l': <double>[-116, 0, -16],
        'shoulder_r': <double>[-48, 0, -10],
        'elbow_r': <double>[-116, 0, 16],
        'spine': <double>[-12, 0, 0],
      },
      rootY: squatRoot - 0.14,
      weighTip: '几乎坐到脚跟上',
      handsTip: '双手环抱双膝',
      mistake: '常见错误：脚踝受力过大',
      lens: lensNewbie);
  add(
      '蹲姿侧影',
      '蹲姿',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-94, 0, 10],
        'knee_l': <double>[106, 0, 0],
        'hip_r': <double>[-94, 0, -10],
        'knee_r': <double>[106, 0, 0],
        'spine': <double>[0, 30, 0],
        'neck': <double>[0, 18, 0],
      },
      rootY: squatRoot,
      weighTip: '侧向展示蹲姿轮廓',
      handsTip: '双手搭膝，目视前方',
      mistake: '常见错误：背部拱起',
      lens: lensAdvanced);

  // ---- 双人 15（单人可演绎的双人位姿势） ----
  add(
      '并肩而立',
      '双人',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[0, 6, 0],
        'neck': <double>[0, 10, 0],
      },
      weighTip: '重心居中，肩膀打开',
      handsTip: '外侧手自然下垂，内侧手轻扶',
      mistake: '常见错误：两人都僵直',
      lens: '35mm 双人全身，机位与胸口齐平');
  add(
      '背靠背',
      '双人',
      '进阶',
      <String, List<double>>{
        'spine': <double>[0, -12, 0],
        'neck': <double>[0, -16, 0],
        'shoulder_l': <double>[6, 0, 26],
        'elbow_l': <double>[-60, 0, -10],
      },
      weighTip: '背部轻贴，重心各自独立',
      handsTip: '双臂自然交叠',
      mistake: '常见错误：互相挤压变形',
      lens: '35mm 双人半身，略低机位');
  add(
      '牵手同行',
      '双人',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[-36, 0, 30],
        'elbow_l': <double>[-30, 0, 0],
        'hip_l': <double>[-16, 0, 2],
        'hip_r': <double>[-6, 0, -2],
        'knee_l': <double>[18, 0, 0],
        'knee_r': <double>[2, 0, 0],
        'spine': <double>[-6, 0, 0],
      },
      rootY: -0.04,
      weighTip: '迈步重心前移',
      handsTip: '内侧手向前伸出相牵',
      mistake: '常见错误：手臂僵直',
      lens: '35mm 侧向跟拍，机位与腰齐平');
  add(
      '对视比心',
      '双人',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[0, -18, 0],
        'neck': <double>[0, -20, 0],
        'shoulder_l': <double>[-32, 0, 34],
        'elbow_l': <double>[-102, 0, -56],
        'shoulder_r': <double>[-32, 0, -34],
        'elbow_r': <double>[-102, 0, 56],
      },
      weighTip: '两人重心相向微倾',
      handsTip: '内侧手比心拼成完整心形',
      mistake: '常见错误：两颗心错位',
      lens: '50mm 双人半身，平机位');
  add(
      '拥抱侧面',
      '双人',
      '进阶',
      <String, List<double>>{
        'spine': <double>[-10, -20, 0],
        'neck': <double>[10, -14, 0],
        'shoulder_l': <double>[-54, 0, 24],
        'elbow_l': <double>[-92, 0, -24],
        'shoulder_r': <double>[-30, 0, -16],
        'elbow_r': <double>[-80, 0, 20],
      },
      weighTip: '重心向对方身上微微倾斜',
      handsTip: '一手搭肩一手环腰',
      mistake: '常见错误：抱姿生硬像摔跤',
      lens: '50mm 侧面半身，机位略低');
  add(
      '一人倚肩',
      '双人',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[0, -22, 0],
        'neck': <double>[12, -24, 0],
      },
      weighTip: '重心靠向同伴肩头',
      handsTip: '外侧手轻挽对方手臂',
      mistake: '常见错误：头压太重让对方歪斜',
      lens: '50mm 双人半身，平机位');
  add(
      '共撑一伞',
      '双人',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[-84, 0, 30],
        'elbow_l': <double>[-36, 0, 0],
        'neck': <double>[6, 0, 0],
      },
      weighTip: '持伞手向上支撑',
      handsTip: '一手握伞柄一手轻扶伞骨',
      mistake: '常见错误：伞沿挡脸',
      lens: '35mm 双人，仰角 10°');
  add(
      '携手起跑',
      '双人',
      '高难度',
      <String, List<double>>{
        'spine': <double>[-12, 0, 0],
        'shoulder_l': <double>[-64, 0, 26],
        'elbow_l': <double>[-40, 0, 0],
        'hip_l': <double>[-34, 0, 4],
        'knee_l': <double>[52, 0, 0],
        'hip_r': <double>[22, 0, -4],
        'knee_r': <double>[24, 0, 0],
      },
      rootY: -0.1,
      weighTip: '起跑姿态，重心压在前脚',
      handsTip: '内侧手向后拉住同伴',
      mistake: '常见错误：步子跨太大失衡',
      lens: '24mm 低角度，强化动势');
  add(
      '面对面轻语',
      '双人',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[-8, -16, 0],
        'neck': <double>[6, -20, 0],
      },
      weighTip: '上身向对方自然倾斜',
      handsTip: '一手轻挡嘴边',
      mistake: '常见错误：脸贴太近',
      lens: '85mm 特写压缩空间');
  add(
      '背手牵引',
      '双人',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[16, 0, -20],
        'elbow_l': <double>[-40, 0, -14],
        'spine': <double>[0, 0, 0],
      },
      weighTip: '身体朝前，手臂后伸',
      handsTip: '内侧手向后牵住对方',
      mistake: '常见错误：手肘外翻',
      lens: '35mm 双人全身，背后跟拍');
  add(
      '同框侧躺',
      '双人',
      '进阶',
      <String, List<double>>{
        'hip_l': <double>[-96, 0, 10],
        'hip_r': <double>[-96, 0, -10],
        'knee_l': <double>[64, 0, 0],
        'knee_r': <double>[64, 0, 0],
        'spine': <double>[-20, 0, 0],
        'neck': <double>[16, 0, 0],
        'shoulder_l': <double>[-40, 0, 44],
        'elbow_l': <double>[-96, 0, -30],
      },
      rootY: -0.6,
      weighTip: '侧躺重心落在肩胛与髋部',
      handsTip: '一手支头一手搭在身上',
      mistake: '常见错误：腰部悬空',
      lens: '35mm 平视侧躺方向');
  add(
      '互相整理衣领',
      '双人',
      '进阶',
      <String, List<double>>{
        'spine': <double>[-6, 14, 0],
        'neck': <double>[6, 16, 0],
        'shoulder_l': <double>[-46, 0, 18],
        'elbow_l': <double>[-96, 0, -20],
        'shoulder_r': <double>[-24, 0, -10],
        'elbow_r': <double>[-72, 0, 12],
      },
      weighTip: '上前半步靠近对方',
      handsTip: '双手轻捏对方衣领',
      mistake: '常见错误：手部动作过粗',
      lens: '50mm 双人半身特写手部');
  add(
      '叠影剪影',
      '双人',
      '高难度',
      <String, List<double>>{
        'spine': <double>[0, 34, 0],
        'neck': <double>[0, 30, 0],
        'shoulder_l': <double>[-30, 0, 34],
        'elbow_l': <double>[-84, 0, -30],
      },
      weighTip: '一人站在同伴斜前方',
      handsTip: '外侧手轻搭对方肩',
      mistake: '常见错误：完全重叠看不清两人',
      lens: '35mm 逆光剪影，机位略低');
  add(
      '轻抵额头',
      '双人',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[-4, -14, 0],
        'neck': <double>[10, -14, 0],
        'shoulder_l': <double>[-24, 0, 30],
        'elbow_l': <double>[-88, 0, -36],
        'shoulder_r': <double>[-24, 0, -30],
        'elbow_r': <double>[-88, 0, 36],
      },
      weighTip: '额头轻触重心稳定',
      handsTip: '双手互握放在胸前',
      mistake: '常见错误：真的用力顶额头',
      lens: '85mm 特写，平机位');
  add(
      '并排坐',
      '双人',
      '新手友好',
      <String, List<double>>{
        'hip_l': <double>[-88, 0, 4],
        'hip_r': <double>[-88, 0, -4],
        'knee_l': <double>[86, 0, 0],
        'knee_r': <double>[86, 0, 0],
        'spine': <double>[0, -8, 0],
        'neck': <double>[0, -10, 0],
      },
      rootY: -0.42,
      weighTip: '并排坐姿重心独立',
      handsTip: '外侧手搭在对方身后',
      mistake: '常见错误：抢座位挤在一起',
      lens: '35mm 正面双人全身');

  // ---- 动态 15 ----
  add(
      '跃起瞬间',
      '动态',
      '高难度',
      <String, List<double>>{
        'shoulder_l': <double>[-110, 0, 44],
        'elbow_l': <double>[-20, 0, 0],
        'shoulder_r': <double>[-110, 0, -44],
        'elbow_r': <double>[-20, 0, 0],
        'hip_l': <double>[-48, 0, 10],
        'knee_l': <double>[36, 0, 0],
        'hip_r': <double>[-48, 0, -10],
        'knee_r': <double>[36, 0, 0],
        'spine': <double>[6, 0, 0],
      },
      rootY: 0.18,
      weighTip: '起跳瞬间全身向上延伸',
      handsTip: '双臂向上打开',
      mistake: '常见错误：起跳前耸肩',
      lens: '24mm 低角度连拍，抓最高点');
  add(
      '甩袖转身',
      '动态',
      '进阶',
      <String, List<double>>{
        'spine': <double>[0, 42, 0],
        'neck': <double>[0, 30, 0],
        'shoulder_l': <double>[-30, 0, 56],
        'elbow_l': <double>[-50, 0, 0],
        'shoulder_r': <double>[-30, 0, -56],
        'elbow_r': <double>[-50, 0, 0],
        'hip_l': <double>[-6, 20, 4],
        'hip_r': <double>[-6, -20, -4],
      },
      weighTip: '旋转带动全身，重心稳定',
      handsTip: '随转身甩开衣袖',
      mistake: '常见错误：只转手臂不转腰',
      lens: '35mm 追随转身轨迹');
  add(
      '奔跑回眸',
      '动态',
      '进阶',
      <String, List<double>>{
        'spine': <double>[-16, 24, 0],
        'neck': <double>[-4, 28, 0],
        'hip_l': <double>[-42, 0, 4],
        'knee_l': <double>[56, 0, 0],
        'hip_r': <double>[26, 0, -4],
        'knee_r': <double>[30, 0, 0],
        'shoulder_l': <double>[-52, 0, 24],
        'elbow_l': <double>[-70, 0, -10],
        'shoulder_r': <double>[42, 0, -20],
        'elbow_r': <double>[-86, 0, 10],
      },
      rootY: -0.08,
      weighTip: '奔跑重心前倾',
      handsTip: '双臂自然摆动',
      mistake: '常见错误：回眸角度太生硬',
      lens: '35mm 跟拍侧后 45°');
  add(
      '旋转裙摆',
      '动态',
      '进阶',
      <String, List<double>>{
        'spine': <double>[0, 54, 0],
        'neck': <double>[0, 20, 0],
        'shoulder_l': <double>[-8, 0, 64],
        'elbow_l': <double>[-30, 0, 0],
        'shoulder_r': <double>[-8, 0, -64],
        'elbow_r': <double>[-30, 0, 0],
      },
      weighTip: '以一脚为轴旋转',
      handsTip: '手臂自然展开保持平衡',
      mistake: '常见错误：裙摆没转起来',
      lens: '35mm 平视，裙摆转开时连拍');
  add(
      '踏水跑动',
      '动态',
      '进阶',
      <String, List<double>>{
        'spine': <double>[-14, 0, 0],
        'hip_l': <double>[-44, 0, 4],
        'knee_l': <double>[50, 0, 0],
        'hip_r': <double>[28, 0, -4],
        'knee_r': <double>[34, 0, 0],
        'shoulder_l': <double>[-58, 0, 20],
        'elbow_l': <double>[-64, 0, 0],
        'shoulder_r': <double>[38, 0, -18],
        'elbow_r': <double>[-80, 0, 0],
      },
      rootY: -0.06,
      weighTip: '步幅放开，重心前压',
      handsTip: '手臂摆动带动跑姿',
      mistake: '常见错误：水花太大失焦',
      lens: '24mm 低角度连拍');
  add(
      '抛洒花瓣',
      '动态',
      '进阶',
      <String, List<double>>{
        'shoulder_l': <double>[-124, 0, 34],
        'elbow_l': <double>[-16, 0, 0],
        'shoulder_r': <double>[-124, 0, -34],
        'elbow_r': <double>[-16, 0, 0],
        'spine': <double>[4, 0, 0],
        'neck': <double>[-10, 0, 0],
      },
      weighTip: '手臂上扬，重心稳定',
      handsTip: '双手向上抛出花瓣',
      mistake: '常见错误：花瓣糊脸',
      lens: '35mm 仰角 15°');
  add(
      '迎风展开',
      '动态',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[-20, 0, 68],
        'elbow_l': <double>[-24, 0, 0],
        'shoulder_r': <double>[-20, 0, -68],
        'elbow_r': <double>[-24, 0, 0],
        'spine': <double>[4, 0, 0],
        'neck': <double>[-8, 0, 0],
      },
      weighTip: '迎风站立，重心后靠',
      handsTip: '双臂自然张开',
      mistake: '常见错误：手臂像广播体操',
      lens: '35mm 正面平拍');
  add(
      '追逐侧影',
      '动态',
      '高难度',
      <String, List<double>>{
        'spine': <double>[-18, 10, 0],
        'hip_l': <double>[-52, 0, 6],
        'knee_l': <double>[40, 0, 0],
        'hip_r': <double>[34, 0, -6],
        'knee_r': <double>[24, 0, 0],
        'shoulder_l': <double>[-64, 0, 26],
        'elbow_l': <double>[-56, 0, 0],
        'shoulder_r': <double>[30, 0, -14],
        'elbow_r': <double>[-92, 0, 0],
      },
      rootY: -0.1,
      weighTip: '跨步最大，重心最低',
      handsTip: '前手前伸，后手后摆',
      mistake: '常见错误：步幅不够显假跑',
      lens: '35mm 侧面跟拍');
  add(
      '腾空劈叉',
      '动态',
      '高难度',
      <String, List<double>>{
        'hip_l': <double>[-42, 0, 22],
        'knee_l': <double>[8, 0, 0],
        'hip_r': <double>[34, 0, -22],
        'knee_r': <double>[8, 0, 0],
        'shoulder_l': <double>[-70, 0, 40],
        'elbow_l': <double>[-30, 0, 0],
        'shoulder_r': <double>[70, 0, -40],
        'elbow_r': <double>[-30, 0, 0],
      },
      rootY: 0.22,
      weighTip: '腾空瞬间核心收紧',
      handsTip: '双臂展开保持平衡',
      mistake: '常见错误：落地不稳',
      lens: '24mm 仰角 20°');
  add(
      '雨中奔跑',
      '动态',
      '进阶',
      <String, List<double>>{
        'spine': <double>[-12, 0, 0],
        'hip_l': <double>[-38, 0, 4],
        'knee_l': <double>[46, 0, 0],
        'hip_r': <double>[22, 0, -4],
        'knee_r': <double>[36, 0, 0],
        'shoulder_l': <double>[-46, 0, 18],
        'elbow_l': <double>[-58, 0, 0],
        'shoulder_r': <double>[32, 0, -14],
        'elbow_r': <double>[-74, 0, 0],
        'neck': <double>[-6, 0, 0],
      },
      rootY: -0.05,
      weighTip: '雨中奔跑注意防滑',
      handsTip: '双手自然摆动',
      mistake: '常见错误：发型糊脸',
      lens: '35mm 连拍抓水花');
  add(
      '原地起跳',
      '动态',
      '高难度',
      <String, List<double>>{
        'shoulder_l': <double>[-104, 0, 30],
        'elbow_l': <double>[-24, 0, 0],
        'shoulder_r': <double>[-104, 0, -30],
        'elbow_r': <double>[-24, 0, 0],
        'hip_l': <double>[-36, 0, 8],
        'knee_l': <double>[44, 0, 0],
        'hip_r': <double>[-36, 0, -8],
        'knee_r': <double>[44, 0, 0],
        'neck': <double>[-8, 0, 0],
      },
      rootY: 0.3,
      weighTip: '垂直起跳，落地屈膝缓冲',
      handsTip: '双臂向上带动身体',
      mistake: '常见错误：起跳无力显假',
      lens: '50mm 平视连拍最高点');
  add(
      '快步转身',
      '动态',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[0, 36, 0],
        'neck': <double>[0, 20, 0],
        'hip_l': <double>[-12, 10, 4],
        'hip_r': <double>[-12, -10, -4],
        'shoulder_l': <double>[-16, 0, 30],
        'elbow_l': <double>[-52, 0, -10],
        'shoulder_r': <double>[-16, 0, -30],
        'elbow_r': <double>[-52, 0, 10],
      },
      rootY: -0.02,
      weighTip: '转身由脚跟发力',
      handsTip: '手臂随转身甩动',
      mistake: '常见错误：转身太慢显摆拍',
      lens: '35mm 环绕跟拍');
  add(
      '扬手挥别',
      '动态',
      '新手友好',
      <String, List<double>>{
        'shoulder_l': <double>[-116, 0, 30],
        'elbow_l': <double>[-24, 0, 0],
        'spine': <double>[0, -10, 0],
        'neck': <double>[0, -12, 0],
      },
      weighTip: '重心在后腿，身体微前倾',
      handsTip: '高抬手左右轻挥',
      mistake: '常见错误：手臂僵直',
      lens: '50mm 半身平拍');
  add(
      '舞动长绸',
      '动态',
      '高难度',
      <String, List<double>>{
        'spine': <double>[0, -32, 0],
        'neck': <double>[0, -20, 0],
        'shoulder_l': <double>[-96, 0, 50],
        'elbow_l': <double>[-30, 0, 0],
        'shoulder_r': <double>[30, 0, -46],
        'elbow_r': <double>[-40, 0, 0],
        'hip_l': <double>[-10, 16, 4],
        'hip_r': <double>[-10, -16, -4],
      },
      weighTip: '以腰为轴带动绸面',
      handsTip: '双手各执绸一端',
      mistake: '常见错误：绸面缠住身体',
      lens: '24mm 捕捉绸面展开瞬间');

  // ---- 情绪 15 ----
  add(
      '低头沉思',
      '情绪',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[-8, 0, 0],
        'neck': <double>[18, 0, 0],
      },
      weighTip: '气息下沉，肩膀放松',
      handsTip: '双手交叠置于身前',
      mistake: '常见错误：下巴抵住锁骨',
      lens: '85mm 半身压缩，浅景深');
  add(
      '掩面落泪',
      '情绪',
      '高难度',
      <String, List<double>>{
        'spine': <double>[-12, 0, 0],
        'neck': <double>[14, 0, 0],
        'shoulder_l': <double>[-64, 0, 4],
        'elbow_l': <double>[-124, 0, -18],
        'shoulder_r': <double>[-64, 0, -4],
        'elbow_r': <double>[-124, 0, 18],
      },
      weighTip: '含胸蜷缩，重心内收',
      handsTip: '双手掩面，指尖轻颤',
      mistake: '常见错误：手挡光让脸全黑',
      lens: '85mm 特写，注意眼部反光');
  add(
      '仰头释然',
      '情绪',
      '进阶',
      <String, List<double>>{
        'spine': <double>[8, 0, 0],
        'neck': <double>[-20, 0, 0],
        'shoulder_l': <double>[6, 0, 18],
        'elbow_l': <double>[-30, 0, 0],
        'shoulder_r': <double>[6, 0, -18],
        'elbow_r': <double>[-30, 0, 0],
      },
      weighTip: '胸腔打开，重心后靠',
      handsTip: '双臂自然下垂',
      mistake: '常见错误：颈部拉伸过猛',
      lens: '50mm 仰角 10°');
  add(
      '抱臂防御',
      '情绪',
      '进阶',
      <String, List<double>>{
        'shoulder_l': <double>[8, 0, 36],
        'elbow_l': <double>[-98, 0, 28],
        'shoulder_r': <double>[8, 0, -32],
        'elbow_r': <double>[-94, 0, -32],
        'spine': <double>[-6, 0, 0],
        'neck': <double>[8, 0, 0],
      },
      weighTip: '重心后移，防备姿态',
      handsTip: '双手环抱护住胸口',
      mistake: '常见错误：手臂遮挡面部轮廓',
      lens: '85mm 半身，侧 45°');
  add(
      '眺望远方',
      '情绪',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[0, 26, 0],
        'neck': <double>[-6, 22, 0],
      },
      weighTip: '重心在前，视线放远',
      handsTip: '一只手轻搭额前或垂下',
      mistake: '常见错误：眼神涣散',
      lens: '85mm 越肩视角');
  add(
      '羞涩浅笑',
      '情绪',
      '新手友好',
      <String, List<double>>{
        'neck': <double>[6, -8, 0],
        'spine': <double>[0, -6, 0],
        'shoulder_l': <double>[-20, 0, 22],
        'elbow_l': <double>[-84, 0, -20],
      },
      weighTip: '身体微微侧转',
      handsTip: '一只手轻掩嘴角',
      mistake: '常见错误：笑得太用力',
      lens: '85mm 特写');
  add(
      '闭目养神',
      '情绪',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[2, 0, 0],
        'neck': <double>[4, 0, 0],
      },
      weighTip: '全身放松，均匀呼吸',
      handsTip: '双手自然交叠',
      mistake: '常见错误：表情管理失去控制',
      lens: '85mm 半身，柔光');
  add(
      '担忧蹙眉',
      '情绪',
      '进阶',
      <String, List<double>>{
        'spine': <double>[-6, 0, 0],
        'neck': <double>[12, 6, 0],
        'shoulder_l': <double>[-24, 0, 20],
        'elbow_l': <double>[-92, 0, -22],
      },
      weighTip: '肩膀微微内扣',
      handsTip: '一只手轻握另一只手腕',
      mistake: '常见错误：表情与动作不匹配',
      lens: '85mm 特写，注意额头光');
  add(
      '坚定注视',
      '情绪',
      '高难度',
      <String, List<double>>{
        'spine': <double>[-2, 0, 0],
        'neck': <double>[-4, 0, 0],
        'shoulder_l': <double>[0, 0, 14],
        'shoulder_r': <double>[0, 0, -14],
      },
      weighTip: '核心收紧，站姿稳定',
      handsTip: '双手握拳置于身侧',
      mistake: '常见错误：目光虚焦',
      lens: '85mm 特写，平机位');
  add(
      '惊喜捂嘴',
      '情绪',
      '新手友好',
      <String, List<double>>{
        'neck': <double>[-6, 0, 0],
        'shoulder_l': <double>[-46, 0, 18],
        'elbow_l': <double>[-116, 0, -20],
        'shoulder_r': <double>[-40, 0, -16],
        'elbow_r': <double>[-104, 0, 16],
      },
      weighTip: '重心微微后仰',
      handsTip: '双手轻捂嘴，眼睛睁大',
      mistake: '常见错误：手把脸挡死',
      lens: '50mm 半身');
  add(
      '思念垂眸',
      '情绪',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[-4, -10, 0],
        'neck': <double>[14, -8, 0],
        'shoulder_l': <double>[-14, 0, 16],
        'elbow_l': <double>[-70, 0, -14],
      },
      weighTip: '身体轻侧，姿态安静',
      handsTip: '指尖轻抚信物/手机',
      mistake: '常见错误：低头遮住全部五官',
      lens: '85mm 越肩特写');
  add(
      '放声大笑',
      '情绪',
      '进阶',
      <String, List<double>>{
        'spine': <double>[8, 0, 0],
        'neck': <double>[-14, 0, 0],
        'shoulder_l': <double>[-20, 0, 36],
        'elbow_l': <double>[-70, 0, -16],
        'shoulder_r': <double>[-20, 0, -36],
        'elbow_r': <double>[-70, 0, 16],
      },
      weighTip: '身体后仰释放情绪',
      handsTip: '双手叉腰或扶膝',
      mistake: '常见错误：后仰过头笑僵',
      lens: '35mm 动态抓拍');
  add(
      '冷艳侧目',
      '情绪',
      '高难度',
      <String, List<double>>{
        'spine': <double>[0, 18, 0],
        'neck': <double>[-2, 14, 0],
        'shoulder_l': <double>[0, 0, 12],
        'shoulder_r': <double>[0, 0, -12],
      },
      weighTip: '重心后移，气场外放',
      handsTip: '双臂自然下垂或插兜',
      mistake: '常见错误：下巴抬太高',
      lens: '85mm 侧 45° 特写');
  add(
      '温柔安抚',
      '情绪',
      '新手友好',
      <String, List<double>>{
        'spine': <double>[-4, -8, 0],
        'neck': <double>[6, -10, 0],
        'shoulder_l': <double>[-40, 0, 24],
        'elbow_l': <double>[-48, 0, 0],
      },
      weighTip: '身体前倾安抚同伴',
      handsTip: '一只手向前轻抚',
      mistake: '常见错误：动作幅度太大',
      lens: '50mm 双人构图');
  add(
      '释然转身',
      '情绪',
      '进阶',
      <String, List<double>>{
        'spine': <double>[0, 30, 0],
        'neck': <double>[0, 26, 0],
        'hip_l': <double>[-8, 12, 4],
        'hip_r': <double>[-8, -12, -4],
        'shoulder_l': <double>[-10, 0, 24],
        'elbow_l': <double>[-46, 0, -10],
        'shoulder_r': <double>[-10, 0, -24],
        'elbow_r': <double>[-46, 0, 10],
      },
      rootY: -0.02,
      weighTip: '转身同时重心向前',
      handsTip: '手臂随笔触自然摆动',
      mistake: '常见错误：头转太快显突兀',
      lens: '35mm 跟随转身');

  // ---- 手部 15 ----
  final handPoses = <List<Object>>[
    <Object>[
      '扶镜框',
      <String, List<double>>{
        'shoulder_l': <double>[-60, 0, 24],
        'elbow_l': <double>[-100, 0, -6],
        'wrist_l': <double>[0, 0, 10],
      }
    ],
    <Object>[
      '手搭肩',
      <String, List<double>>{
        'shoulder_l': <double>[-40, 0, 6],
        'elbow_l': <double>[-108, 0, -30],
        'wrist_l': <double>[0, 0, -10],
      }
    ],
    <Object>[
      '捧脸颊',
      <String, List<double>>{
        'shoulder_l': <double>[-48, 0, 8],
        'elbow_l': <double>[-118, 0, -18],
        'wrist_l': <double>[0, 0, -16],
        'neck': <double>[6, 0, 0],
      }
    ],
    <Object>[
      '指尖触唇',
      <String, List<double>>{
        'shoulder_l': <double>[-54, 0, 12],
        'elbow_l': <double>[-112, 0, -14],
        'wrist_l': <double>[0, 0, 12],
        'neck': <double>[4, 0, 0],
      }
    ],
    <Object>[
      '比耶',
      <String, List<double>>{
        'shoulder_l': <double>[-52, 0, 40],
        'elbow_l': <double>[-64, 0, 0],
        'wrist_l': <double>[-8, 0, 0],
      }
    ],
    <Object>[
      'OK 手势',
      <String, List<double>>{
        'shoulder_l': <double>[-40, 0, 34],
        'elbow_l': <double>[-72, 0, -8],
        'wrist_l': <double>[6, 0, 0],
      }
    ],
    <Object>[
      '竖大拇指',
      <String, List<double>>{
        'shoulder_l': <double>[-46, 0, 28],
        'elbow_l': <double>[-60, 0, -6],
        'wrist_l': <double>[-14, 0, 0],
      }
    ],
    <Object>[
      '拳头握紧',
      <String, List<double>>{
        'shoulder_l': <double>[-30, 0, 24],
        'elbow_l': <double>[-84, 0, -12],
        'wrist_l': <double>[0, 0, 0],
      }
    ],
    <Object>[
      '双手交握',
      <String, List<double>>{
        'shoulder_l': <double>[-30, 0, 36],
        'elbow_l': <double>[-96, 0, -26],
        'wrist_l': <double>[0, 0, -12],
        'shoulder_r': <double>[-30, 0, -36],
        'elbow_r': <double>[-96, 0, 26],
        'wrist_r': <double>[0, 0, 12],
      }
    ],
    <Object>[
      '指尖轻点下巴',
      <String, List<double>>{
        'shoulder_l': <double>[-62, 0, 10],
        'elbow_l': <double>[-118, 0, -10],
        'wrist_l': <double>[0, 0, 8],
        'neck': <double>[4, 6, 0],
      }
    ],
    <Object>[
      '手背贴额头',
      <String, List<double>>{
        'shoulder_l': <double>[-70, 0, 16],
        'elbow_l': <double>[-110, 0, -6],
        'wrist_l': <double>[12, 0, 0],
      }
    ],
    <Object>[
      '手指按太阳穴',
      <String, List<double>>{
        'shoulder_l': <double>[-56, 0, 18],
        'elbow_l': <double>[-118, 0, -12],
        'wrist_l': <double>[8, 0, 0],
        'neck': <double>[6, 0, 0],
      }
    ],
    <Object>[
      '手掌挡嘴',
      <String, List<double>>{
        'shoulder_l': <double>[-50, 0, 14],
        'elbow_l': <double>[-116, 0, -16],
        'wrist_l': <double>[0, 0, -6],
      }
    ],
    <Object>[
      '手搭腰侧',
      <String, List<double>>{
        'shoulder_l': <double>[-18, 0, 30],
        'elbow_l': <double>[-96, 0, -52],
        'wrist_l': <double>[0, 0, -18],
      }
    ],
    <Object>[
      '指尖交叠胸前',
      <String, List<double>>{
        'shoulder_l': <double>[-36, 0, 30],
        'elbow_l': <double>[-100, 0, -34],
        'wrist_l': <double>[0, 0, -10],
        'shoulder_r': <double>[-36, 0, -30],
        'elbow_r': <double>[-100, 0, 34],
        'wrist_r': <double>[0, 0, 10],
      }
    ],
  ];
  for (final entry in handPoses) {
    final name = entry[0] as String;
    final overrides = entry[1] as Map<String, List<double>>;
    add(name, '手部', '新手友好', overrides,
        weighTip: '身体保持自然站姿，让手部成为画面焦点',
        handsTip: '手指关节放松，避免并拢僵直',
        mistake: '常见错误：手腕角度生硬',
        lens: '85mm 手部特写，浅景深');
  }

  for (final Map<String, Object?> pose in poses) {
    pose['cameraPosition'] = _cameraPosition(
      pose['category'] as String,
      pose['difficulty'] as String,
    );
  }
  return poses;
}

String _cameraPosition(String category, String difficulty) {
  switch (category) {
    case '坐姿':
      return '机位与坐姿视线齐平，保留环境空间交代场景';
    case '动态':
      return '机位预留运动方向空间，连拍抓取最自然的一帧';
    case '手部':
      return '85mm 手部特写，浅景深，机位与手部齐平';
    case '双人':
      return '双人构图居中，机位与胸口齐平，注意两人视线落点';
    case '蹲跪':
      return '略低机位（腰位），突出低姿态的线条张力';
    case '情绪':
      return '正面或侧 30° 特写，留白烘托情绪，注意眼神光';
    default:
      if (difficulty == '高难度') return '低机位仰拍或高机位俯拍，控好透视畸变';
      if (difficulty == '进阶') return '机位略低（腰位），45° 侧向压缩层次';
      return '机位与胸口齐平，正面或 30° 侧向，稳妥出片';
  }
}

// ---------------- 策划模板 ----------------
Map<String, Object?> _mod(String type, String title,
        [Map<String, Object?>? preset]) =>
    <String, Object?>{
      'type': type,
      'title': title,
      'preset': preset ?? <String, Object?>{}
    };

List<Map<String, Object?>> _templates() {
  Map<String, Object?> t(String id, String name, String category,
          String description, List<Map<String, Object?>> modules) =>
      <String, Object?>{
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'modules': modules
      };

  final crewBase = <Object?>[
    <String, Object?>{'role': '摄影师', 'who': '', 'time': '10:00'},
    <String, Object?>{'role': '妆造', 'who': '', 'time': '08:30'},
    <String, Object?>{'role': '后勤', 'who': '', 'time': '10:00'},
  ];
  final budgetBase = <Object?>[
    <String, Object?>{'item': '场地', 'price': 300, 'note': ''},
    <String, Object?>{'item': '妆造', 'price': 400, 'note': ''},
    <String, Object?>{'item': '交通餐饮', 'price': 150, 'note': ''},
  ];

  return <Map<String, Object?>>[
    t('tpl-cos', 'Cosplay 正片模板', 'Cos 正片',
        '角色还原 · 场景与配色对齐 · 9 模块起手', <Map<String, Object?>>[
      _mod('theme', '拍摄主题', <String, Object?>{'text': '角色还原，注意神态、服化道与配色一致性'}),
      _mod('model', '模特绑定'),
      _mod('location', '场地绑定'),
      _mod('sun', '日照时间',
          <String, Object?>{'place': '上海', 'lat': 31.23, 'lon': 121.47}),
      _mod('refs', '参考样片'),
      _mod('palette', '色调色卡'),
      _mod('lighting', '布光图'),
      _mod('poses', '姿势清单'),
      _mod('clothing', '服装清单', <String, Object?>{'note': '正片服装 + 备用件 + 安全裤'}),
      _mod('makeup', '妆面造型', <String, Object?>{'note': '假睫毛/美瞳/发网按角色准备'}),
      _mod('crew', '人员分工', <String, Object?>{'rows': crewBase}),
      _mod('budget', '预算表', <String, Object?>{'rows': budgetBase}),
    ]),
    t('tpl-hanfu', '汉服外景模板', '汉服',
        '国风意境 · 晨昏光线窗口 · 衣料质感', <Map<String, Object?>>[
      _mod('theme', '拍摄主题', <String, Object?>{'text': '国风意境，轻叙事，突出衣料垂坠与配色'}),
      _mod('model', '模特绑定'),
      _mod('location', '场地绑定'),
      _mod('sun', '日照时间',
          <String, Object?>{'place': '杭州', 'lat': 30.27, 'lon': 120.16}),
      _mod('refs', '参考样片'),
      _mod('palette', '色调色卡'),
      _mod('poses', '姿势清单'),
      _mod('clothing', '服装清单', <String, Object?>{'note': '襦裙 + 大袖衫，注意风况与裙摆'}),
      _mod('makeup', '妆面造型', <String, Object?>{'note': '古风妆 + 发髻假发包'}),
      _mod('crew', '人员分工', <String, Object?>{'rows': crewBase}),
      _mod('budget', '预算表', <String, Object?>{'rows': budgetBase}),
    ]),
    t('tpl-jk', 'JK 校园写真模板', 'JK', '青春校园感 · 生活化抓拍', <Map<String, Object?>>[
      _mod('theme', '拍摄主题', <String, Object?>{'text': '青春校园感，生活化抓拍，自然光优先'}),
      _mod('model', '模特绑定'),
      _mod('location', '场地绑定'),
      _mod('sun', '日照时间',
          <String, Object?>{'place': '成都', 'lat': 30.57, 'lon': 104.07}),
      _mod('refs', '参考样片'),
      _mod('poses', '姿势清单'),
      _mod('clothing', '服装清单', <String, Object?>{'note': '格裙/水手服两套 + 领结'}),
      _mod('makeup', '妆面造型', <String, Object?>{'note': '伪素颜清透妆'}),
      _mod('crew', '人员分工', <String, Object?>{'rows': crewBase}),
    ]),
    t('tpl-wedding', '婚纱旅拍模板', '婚纱',
        '仪式感叙事 · 黄金时刻窗口 · 双人姿势', <Map<String, Object?>>[
      _mod('theme', '拍摄主题', <String, Object?>{'text': '仪式感叙事，纪实与摆拍结合，抓真实情绪'}),
      _mod('model', '新人绑定', <String, Object?>{'note': '提前试妆，确认时间线'}),
      _mod('location', '场地绑定'),
      _mod('sun', '日照时间',
          <String, Object?>{'place': '大理', 'lat': 25.61, 'lon': 100.27}),
      _mod('refs', '参考样片'),
      _mod('palette', '色调色卡'),
      _mod('poses', '姿势清单'),
      _mod('clothing', '服装清单', <String, Object?>{'note': '主纱 + 敬酒服 + 外景轻纱'}),
      _mod('crew', '人员分工', <String, Object?>{'rows': crewBase}),
      _mod('budget', '预算表', <String, Object?>{'rows': budgetBase}),
    ]),
    t('tpl-studio', '棚拍写真模板', '写真',
        '情绪人像 · 光比控制 · 布光图先行', <Map<String, Object?>>[
      _mod('theme', '拍摄主题', <String, Object?>{'text': '情绪人像，棚拍光比控制，突出面部结构'}),
      _mod('model', '模特绑定'),
      _mod('refs', '参考样片'),
      _mod('palette', '色调色卡'),
      _mod('lighting', '布光图'),
      _mod('poses', '姿势清单'),
      _mod('clothing', '服装清单', <String, Object?>{'note': '纯色系 3 套'}),
      _mod('makeup', '妆面造型', <String, Object?>{'note': '轻氧妆'}),
      _mod('crew', '人员分工', <String, Object?>{'rows': crewBase}),
      _mod('budget', '预算表', <String, Object?>{'rows': budgetBase}),
    ]),
    t('tpl-commerce', '商拍人像模板', '商拍', '品牌调性 · 统一构图与留白', <Map<String, Object?>>[
      _mod('theme', '拍摄主题', <String, Object?>{'text': '品牌调性统一，构图留白，注意产品露出'}),
      _mod('model', '模特绑定', <String, Object?>{'note': '按品牌风格筛选'}),
      _mod('refs', '参考样片'),
      _mod('palette', '色调色卡'),
      _mod('lighting', '布光图'),
      _mod('clothing', '服装清单', <String, Object?>{'note': '品牌样衣 5 套'}),
      _mod('props', '道具清单', <String, Object?>{'note': '产品陈列道具'}),
      _mod('crew', '人员分工', <String, Object?>{'rows': crewBase}),
      _mod('budget', '预算表', <String, Object?>{'rows': budgetBase}),
    ]),
    t('tpl-lolita', 'Lolita 棚拍模板', 'Lo裙',
        '甜美梦幻 · 低角度裙型展示', <Map<String, Object?>>[
      _mod('theme', '拍摄主题', <String, Object?>{'text': '甜美梦幻，裙型展示优先，柔光低反差'}),
      _mod('model', '模特绑定'),
      _mod('refs', '参考样片'),
      _mod('palette', '色调色卡'),
      _mod('lighting', '布光图'),
      _mod('poses', '姿势清单'),
      _mod('clothing', '服装清单', <String, Object?>{'note': '主裙 + 头饰 + 手袖'}),
      _mod('makeup', '妆面造型', <String, Object?>{'note': '甜美妆，注意与裙色协调'}),
      _mod('crew', '人员分工', <String, Object?>{'rows': crewBase}),
    ]),
    t('tpl-couple', '双人互动模板', '双人', '关系叙事 · 双人姿势与站位', <Map<String, Object?>>[
      _mod('theme', '拍摄主题', <String, Object?>{'text': '关系叙事，互动自然，避免摆拍感'}),
      _mod('model', '双人绑定'),
      _mod('location', '场地绑定'),
      _mod('sun', '日照时间',
          <String, Object?>{'place': '北京', 'lat': 39.90, 'lon': 116.40}),
      _mod('refs', '参考样片'),
      _mod('lighting', '布光图'),
      _mod('poses', '姿势清单', <String, Object?>{'note': '优先双人分类姿势'}),
      _mod('crew', '人员分工', <String, Object?>{'rows': crewBase}),
      _mod('budget', '预算表', <String, Object?>{'rows': budgetBase}),
    ]),
  ];
}

// ---------------- 影片索引 ----------------
List<Map<String, Object?>> _films() {
  final data = <List<Object>>[
    <Object>[
      '花样年华',
      '王家卫',
      2000,
      ['暖褐', '霓虹', '走廊'],
      100,
      70,
      45
    ],
    <Object>[
      '重庆森林',
      '王家卫',
      1994,
      ['霓虹', '暗调', '手持'],
      90,
      60,
      120
    ],
    <Object>[
      '布达佩斯大饭店',
      '韦斯·安德森',
      2014,
      ['粉色', '对称', '构图'],
      240,
      140,
      150
    ],
    <Object>[
      '银翼杀手2049',
      '丹尼斯·维伦纽瓦',
      2017,
      ['橙青', '雾气', '巨型'],
      230,
      110,
      60
    ],
    <Object>[
      '爱乐之城',
      '达米恩·查泽雷',
      2016,
      ['蓝紫', '夜景', '歌舞'],
      70,
      90,
      200
    ],
    <Object>[
      '海上钢琴师',
      '朱塞佩·托纳多雷',
      1998,
      ['暖黄', '怀旧', '海'],
      200,
      160,
      100
    ],
    <Object>[
      '情书',
      '岩井俊二',
      1995,
      ['雪白', '清冷', '逆光'],
      220,
      230,
      240
    ],
    <Object>[
      '银娇',
      '郑址宇',
      2012,
      ['柔和', '自然光', '青春'],
      200,
      190,
      170
    ],
    <Object>[
      '卧虎藏龙',
      '李安',
      2000,
      ['墨绿', '竹林', '留白'],
      60,
      90,
      70
    ],
    <Object>[
      '一代宗师',
      '王家卫',
      2013,
      ['金棕', '雨夜', '特写'],
      150,
      110,
      60
    ],
    <Object>[
      '你的名字',
      '新海诚',
      2016,
      ['暮色', '橙蓝', '天空'],
      250,
      130,
      90
    ],
    <Object>[
      '天气之子',
      '新海诚',
      2019,
      ['蓝雨', '光斑', '都市'],
      90,
      160,
      230
    ],
    <Object>[
      '千与千寻',
      '宫崎骏',
      2001,
      ['红灯笼', '暖光', '幻想'],
      210,
      90,
      70
    ],
    <Object>[
      '路边野餐',
      '毕赣',
      2015,
      ['潮湿', '绿调', '长镜'],
      90,
      110,
      90
    ],
    <Object>[
      '白日焰火',
      '刁亦男',
      2014,
      ['冷蓝', '雪夜', '黑色'],
      60,
      80,
      120
    ],
    <Object>[
      '燃烧女子的肖像',
      '瑟琳·席安玛',
      2019,
      ['烛光', '古典', '蓝绿'],
      60,
      110,
      130
    ],
    <Object>[
      '小妇人',
      '格蕾塔·葛韦格',
      2019,
      ['暖阳', '复古', '群像'],
      230,
      180,
      120
    ],
    <Object>[
      '请以你的名字呼唤我',
      '卢卡·瓜达尼诺',
      2017,
      ['夏日', '绿荫', '阳光'],
      160,
      200,
      120
    ],
    <Object>[
      '午夜巴黎',
      '伍迪·艾伦',
      2011,
      ['金黄', '雨夜', '复古'],
      220,
      180,
      80
    ],
    <Object>[
      '她',
      '斯派克·琼斯',
      2013,
      ['暖橙', '都市', '柔和'],
      230,
      140,
      100
    ],
    <Object>[
      '沙丘',
      '丹尼斯·维伦纽瓦',
      2021,
      ['沙金', '巨型', '迷雾'],
      220,
      180,
      130
    ],
    <Object>[
      '蝙蝠侠',
      '马特·里夫斯',
      2022,
      ['暗橙', '雨夜', '霓虹'],
      200,
      90,
      60
    ],
    <Object>[
      '花样年华 2001',
      '王家卫',
      2001,
      ['蓝绿', '旗袍', '走廊'],
      60,
      120,
      110
    ],
    <Object>[
      '海街日记',
      '是枝裕和',
      2015,
      ['清新', '自然光', '日常', '日系'],
      200,
      210,
      190
    ],
  ];

  final films = <Map<String, Object?>>[];
  for (var i = 0; i < data.length; i++) {
    final row = data[i];
    final title = row[0] as String;
    final director = row[1] as String;
    final year = row[2] as int;
    final tags = row[3] as List<String>;
    final r = row[4] as int, g = row[5] as int, b = row[6] as int;
    final frames = <Map<String, Object?>>[];
    for (var f = 0; f < 6; f++) {
      final t = f / 5;
      final r2 = (r + (255 - r) * t * 0.35).round();
      final g2 = (g + 40 * t).round().clamp(0, 255);
      final b2 = (b + (60 - b) * t).round().clamp(0, 255);
      final palette = <String>[
        _hex(r, g, b),
        _hex(r2, g2, b2),
        _hex((r * 0.6).round(), (g * 0.6).round(), (b * 0.7).round()),
        _hex((r * 1.3).clamp(0, 255), (g * 1.2).clamp(0, 255),
            (b * 1.1).clamp(0, 255)),
        _hex(240 - f * 8, 236 - f * 6, 228 - f * 5),
      ];
      frames.add(<String, Object?>{
        'name': '$title · 第 ${f + 1} 帧（${tags[f % tags.length]}）',
        'palette': palette,
        'gradient': <String>[_hex(r, g, b), _hex(r2, g2, b2)],
        'description': '${tags[f % tags.length]}氛围参考帧，适合提取色调与构图语言',
        'sourceUrl': 'https://film-grab.com/?s=${Uri.encodeComponent(title)}',
        'tags': <String>[tags[f % tags.length], '电影'],
      });
    }
    films.add(<String, Object?>{
      'id': 'film-${(i + 1).toString().padLeft(3, '0')}',
      'title': title,
      'director': director,
      'year': year,
      'tags': tags,
      'sourceUrl': 'https://film-grab.com/?s=${Uri.encodeComponent(title)}',
      'frames': frames,
    });
  }
  return films;
}

void main() {
  writeJson('assets/content/light_presets/light_presets.json',
      <String, Object?>{'version': 1, 'presets': _presets()});
  final poses = _poses();
  writeJson('assets/content/poses/poses.json',
      <String, Object?>{'version': 1, 'poses': poses});
  writeJson('assets/content/templates/templates.json',
      <String, Object?>{'version': 1, 'templates': _templates()});
  final films = _films();
  writeJson('assets/content/films/films.json',
      <String, Object?>{'version': 1, 'films': films});
  stdout.writeln('presets=${_presets().length} poses=${poses.length} '
      'templates=${_templates().length} films=${films.length}');
}
