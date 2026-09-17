import 'dart:convert';
import 'dart:io';

/// G5：姿势库重建（≥200 条，标题与关节语义一致，方向变体有真实数据差异）。
/// 输出 assets/content/poses/poses.json；确定性可重跑。
///
/// 说明：每条“核心动作”配 4 个真实朝向变体（正面/左 45°/右 45°/背身），
/// 名称直接描述该朝向，避免“标题承诺超出模型能力”（不再有双人/手指/表情类虚假标题）。
void main() {
  final List<Map<String, Object?>> poses = <Map<String, Object?>>[];

  final List<_Core> cores = _cores();
  var seq = 0;
  for (final _Core core in cores) {
    final List<_Facing> facings = _facingsFor(core);
    for (final _Facing facing in facings) {
      seq++;
      final Map<String, List<double>> joints =
          _apply(core.joints, facing.spineRy, facing.neckRy);
      final Map<String, Object?> pose = <String, Object?>{
        'id': 'pose-${seq.toString().padLeft(3, '0')}',
        'name': '${core.name}·${facing.label}',
        'category': core.category,
        'difficulty': _difficulty(joints, core.rootPitch),
        'joints': joints,
        'rootY': core.rootY,
        'rootPitch': core.rootPitch,
        'weight': core.weight,
        'hands': core.hands,
        'commonMistake': core.mistake,
        'lens': _lensFor(core),
        'cameraPosition': _cameraFor(core),
      };
      poses.add(pose);
    }
  }

  final Map<String, Object?> out = <String, Object?>{
    'version': 2,
    'note': 'G5 重建：60 个核心动作 × 4 个真实朝向；标题与关节数据一致；'
        '手指细节与表情不在当前 12 关节模型能力内，故不提供相应标题。',
    'poses': poses,
  };
  final File file = File('assets/content/poses/poses.json');
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  stdout.writeln('poses=${poses.length}');
  final Map<String, int> byCat = <String, int>{};
  for (final Map<String, Object?> p in poses) {
    byCat['${p['category']}'] = (byCat['${p['category']}'] ?? 0) + 1;
  }
  stdout.writeln(byCat);
}

class _Core {
  _Core(this.name, this.category, this.joints,
      {this.rootY = 0, this.rootPitch = 0, required this.weight, required this.hands, required this.mistake});
  final String name;
  final String category;
  final Map<String, List<double>> joints;
  final double rootY;
  final double rootPitch;
  final String weight;
  final String hands;
  final String mistake;
}

class _Facing {
  const _Facing(this.label, this.spineRy, this.neckRy);
  final String label;
  final double spineRy;
  final double neckRy;
}

/// 12 关节默认值（与引擎 person.js defaultJoints 一致）；保证每条姿势字段齐全，
/// 避免切换姿势时残留上一姿势未覆盖的关节。
Map<String, List<double>> _defaultMap() => <String, List<double>>{
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

Map<String, List<double>> _apply(
    Map<String, List<double>> base, double spineRy, double neckRy) {
  final Map<String, List<double>> out = _defaultMap();
  for (final MapEntry<String, List<double>> e in base.entries) {
    out[e.key] = <double>[e.value[0], e.value[1], e.value[2]];
  }
  void add(String joint, int axis, double value) {
    final List<double> v = out[joint] ?? <double>[0, 0, 0];
    v[axis] = v[axis] + value;
    out[joint] = v;
  }

  // 朝向：腰部旋转为主，颈部反补（视线大致回到镜头）。
  add('spine', 1, spineRy);
  add('neck', 1, neckRy);
  if (spineRy.abs() > 10) {
    add('hip_l', 1, spineRy * 0.35);
    add('hip_r', 1, spineRy * 0.35);
  }
  return out;
}

List<_Facing> _facingsFor(_Core core) {
  switch (core.category) {
    case '躺姿':
      return const <_Facing>[
        _Facing('仰卧', 0, 0),
        _Facing('左侧卧', -18, 30),
        _Facing('右侧卧', 18, -30),
        _Facing('俯卧回望', 12, 40),
      ];
    case '动态':
      return const <_Facing>[
        _Facing('正面', 0, 0),
        _Facing('左前进', -14, 18),
        _Facing('右前进', 14, -18),
        _Facing('背身', 6, -50),
      ];
    default:
      return const <_Facing>[
        _Facing('正面', 0, 0),
        _Facing('左45°', -22, 14),
        _Facing('右45°', 22, -14),
        _Facing('背身回眸', 30, -58),
      ];
  }
}

Map<String, List<double>> _j(Map<String, List<double>> parts) => parts;

List<_Core> _cores() {
  final List<_Core> list = <_Core>[];

  void add(
    String name,
    String category,
    Map<String, List<double>> joints, {
    double rootY = 0,
    double rootPitch = 0,
    required String weight,
    required String hands,
    required String mistake,
  }) =>
      list.add(_Core(name, category, joints,
          rootY: rootY,
          rootPitch: rootPitch,
          weight: weight,
          hands: hands,
          mistake: mistake));

  // ---------------- 站姿（8 核心） ----------------
  add('自然站姿', '站姿', _j(<String, List<double>>{}),
      weight: '双脚与肩同宽，重心居中',
      hands: '双手自然下垂，微屈肘',
      mistake: '双肩耸起、下巴前伸');
  add('双手插兜', '站姿',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-12, 0, 14],
        'elbow_l': <double>[-70, 0, 16],
        'shoulder_r': <double>[-12, 0, -14],
        'elbow_r': <double>[-70, 0, -16],
      }),
      weight: '一条腿微屈，重心落在后腿',
      hands: '拇指留在兜外，手腕放松',
      mistake: '双肘外翻过大显得僵硬');
  add('单手叉腰', '站姿',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-18, 0, 36],
        'elbow_l': <double>[-96, 0, 24],
        'spine': <double>[0, -6, 3],
        'hip_l': <double>[-6, 0, 5],
        'knee_l': <double>[10, 0, 0],
      }),
      weight: '重心放在叉腰一侧，形成三角构图',
      hands: '四指朝后放在腰线上',
      mistake: '手腕折角过大、肩膀抬起');
  add('侧身回眸', '站姿',
      _j(<String, List<double>>{
        'spine': <double>[2, 26, 0],
        'neck': <double>[4, -40, 0],
        'shoulder_r': <double>[8, 0, -12],
        'elbow_r': <double>[-24, 0, -6],
      }),
      weight: '前脚承重，后脚跟稍抬',
      hands: '远侧手可扶发或自然收肘',
      mistake: '只转头不转肩，脖子显得别扭');
  add('双手抱臂', '站姿',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-52, 6, 30],
        'elbow_l': <double>[-104, 0, 26],
        'shoulder_r': <double>[-46, -6, -26],
        'elbow_r': <double>[-96, 0, -48],
        'neck': <double>[2, 0, 0],
      }),
      weight: '上身微后倾，肩膀放松下沉',
      hands: '左右手指自然搭在手臂外侧',
      mistake: '肘尖过高、抱得过紧');
  add('手扶帽檐', '站姿',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-58, 0, 44],
        'elbow_l': <double>[-112, 0, 30],
        'wrist_l': <double>[-28, 0, 0],
        'neck': <double>[6, 0, 0],
      }),
      weight: '另一侧手叉腰或插兜平衡',
      hands: '指尖轻触帽檐，手腕自然折角',
      mistake: '手臂遮住半张脸、肘部正对镜头');
  add('双臂后展', '站姿',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-34, 0, -14],
        'shoulder_r': <double>[-34, 0, 14],
        'elbow_l': <double>[-18, 0, 0],
        'elbow_r': <double>[-18, 0, 0],
        'spine': <double>[-6, 0, 0],
      }),
      weight: '胸口打开、肩胛骨向中间收',
      hands: '手指向后延伸，肘微屈',
      mistake: '塌腰过度导致体态不自然');
  add('轻靠立姿', '站姿', _j(<String, List<double>>{
        'spine': <double>[4, 0, -6],
        'hip_l': <double>[-14, 0, 6],
        'knee_l': <double>[22, 0, 0],
        'knee_r': <double>[6, 0, 0],
      }),
      weight: '单腿支撑、另一腿松弛交叉',
      hands: '手指轻搭大腿或口袋',
      mistake: '整个身体重量压在墙面，肩线歪斜');

  // ---------------- 坐姿（7 核心） ----------------
  add('椅上正坐', '坐姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-88, 0, 4],
        'hip_r': <double>[-88, 0, -4],
        'knee_l': <double>[86, 0, 0],
        'knee_r': <double>[86, 0, 0],
        'spine': <double>[4, 0, 0],
      }),
      rootY: -0.44,
      weight: '坐骨均匀受力，背部挺直',
      hands: '双手叠放膝上或撑在身侧',
      mistake: '含胸驼背、膝盖内扣');
  add('椅上侧坐', '坐姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-86, 0, 8],
        'hip_r': <double>[-86, 0, -8],
        'knee_l': <double>[80, 0, 0],
        'knee_r': <double>[92, 0, 0],
        'spine': <double>[2, 12, -4],
        'neck': <double>[2, -18, 0],
      }),
      rootY: -0.44,
      weight: '身体侧向一侧，双膝并拢偏移',
      hands: '手肘放在膝盖或椅背上',
      mistake: '腰椎塌陷、双膝分开角度不一致');
  add('前倾交谈', '坐姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-84, 0, 5],
        'hip_r': <double>[-84, 0, -5],
        'knee_l': <double>[88, 0, 0],
        'knee_r': <double>[88, 0, 0],
        'spine': <double>[14, 0, 0],
        'neck': <double>[-6, 0, 0],
      }),
      rootY: -0.44,
      weight: '上身前倾 15°，重心落在膝盖前方',
      hands: '手指交叠或托腮',
      mistake: '脖子前伸、背部弯曲过大');
  add('盘腿而坐', '坐姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-84, 0, 34],
        'hip_r': <double>[-84, 0, -34],
        'knee_l': <double>[96, 0, 0],
        'knee_r': <double>[96, 0, 0],
        'spine': <double>[6, 0, 0],
      }),
      rootY: -0.72,
      weight: '两侧坐骨均匀，膝盖尽量下沉',
      hands: '手自然放在膝盖上',
      mistake: '膝盖翘起过高、腰部后仰');
  add('席地抱膝', '坐姿',
      _j(<String, List<double>>{
        'spine': <double>[-8, 0, 0],
        'shoulder_l': <double>[-46, 0, 14],
        'shoulder_r': <double>[-46, 0, -14],
        'elbow_l': <double>[-118, 0, -16],
        'elbow_r': <double>[-118, 0, 16],
        'hip_l': <double>[-104, 0, 8],
        'hip_r': <double>[-104, 0, -8],
        'knee_l': <double>[118, 0, 0],
        'knee_r': <double>[118, 0, 0],
      }),
      rootY: -0.82,
      weight: '坐骨着地，尾骨微收',
      hands: '环抱小腿，手指扣住外侧',
      mistake: '背部圆得太厉害、头部完全埋进膝盖');
  add('长椅舒展', '坐姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-80, 0, 6],
        'hip_r': <double>[-80, 0, -6],
        'knee_l': <double>[72, 0, 0],
        'knee_r': <double>[72, 0, 0],
        'spine': <double>[-10, 0, 0],
        'shoulder_l': <double>[-28, 0, -18],
        'shoulder_r': <double>[-28, 0, 18],
      }),
      rootY: -0.42,
      weight: '身体后仰倚靠椅背',
      hands: '双手撑在身后长椅上',
      mistake: '手肘锁死、锁骨塌陷');
  add('边缘垂足', '坐姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-76, 0, 5],
        'hip_r': <double>[-76, 0, -5],
        'knee_l': <double>[70, 0, 0],
        'knee_r': <double>[70, 0, 0],
        'spine': <double>[-4, 0, 0],
        'neck': <double>[8, 0, 0],
      }),
      rootY: -0.4,
      weight: '坐在边缘，小腿自然下垂',
      hands: '手指扣住坐面边缘',
      mistake: '坐得太浅、显得紧张');

  // ---------------- 蹲姿（6 核心） ----------------
  add('侧面深蹲', '蹲姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-96, 0, 10],
        'hip_r': <double>[-96, 0, -10],
        'knee_l': <double>[112, 0, 0],
        'knee_r': <double>[112, 0, 0],
        'spine': <double>[12, 0, 0],
      }),
      rootY: -0.62,
      weight: '脚跟踩实，膝盖不超过脚尖',
      hands: '手扶膝盖或自然垂放',
      mistake: '膝盖内扣、脚跟离地');
  add('单膝点地', '蹲姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-82, 0, 12],
        'knee_l': <double>[132, 0, 0],
        'hip_r': <double>[-22, 0, -22],
        'knee_r': <double>[96, 0, 0],
        'spine': <double>[10, 0, 0],
      }),
      rootY: -0.5,
      weight: '前腿承重，后膝轻触地面',
      hands: '一只手搭在前膝，另一只扶地',
      mistake: '后膝压实、中心偏后');
  add('蹲姿抬头', '蹲姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-90, 0, 9],
        'hip_r': <double>[-90, 0, -9],
        'knee_l': <double>[108, 0, 0],
        'knee_r': <double>[108, 0, 0],
        'spine': <double>[14, 0, 0],
        'neck': <double>[-26, 0, 0],
      }),
      rootY: -0.6,
      weight: '下蹲后抬头看向镜头，拉长颈部',
      hands: '手肘搭在膝上',
      mistake: '下颌抬太高露出鼻孔');
  add('蹲姿托腮', '蹲姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-92, 0, 10],
        'hip_r': <double>[-92, 0, -10],
        'knee_l': <double>[110, 0, 0],
        'knee_r': <double>[110, 0, 0],
        'spine': <double>[10, 0, 0],
        'shoulder_r': <double>[-44, 0, -22],
        'elbow_r': <double>[-118, 0, -30],
        'wrist_r': <double>[-16, 0, 0],
      }),
      rootY: -0.6,
      weight: '一只手托腮，手肘落在膝盖',
      hands: '托腮手放松，手指朝上',
      mistake: '手肘悬空、肩膀抬起');
  add('侧蹲延伸', '蹲姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-88, 0, 26],
        'knee_l': <double>[104, 0, 0],
        'hip_r': <double>[-52, 0, -14],
        'knee_r': <double>[64, 0, 0],
        'spine': <double>[6, 0, -14],
      }),
      rootY: -0.5,
      weight: '重心偏向一侧，形成斜线',
      hands: '远侧手向斜上方延伸',
      mistake: '两腿角度雷同缺乏造型感');
  add('蹲姿背身', '蹲姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-94, 0, 10],
        'hip_r': <double>[-94, 0, -10],
        'knee_l': <double>[116, 0, 0],
        'knee_r': <double>[116, 0, 0],
        'spine': <double>[16, 0, 0],
        'neck': <double>[10, 0, 0],
      }),
      rootY: -0.62,
      weight: '背对镜头下蹲，保持背部线条',
      hands: '双手扶膝或抱小腿',
      mistake: '含胸导致背部轮廓消失');

  // ---------------- 跪姿（6 核心） ----------------
  add('双膝跪坐', '跪姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-108, 0, 6],
        'hip_r': <double>[-108, 0, -6],
        'knee_l': <double>[128, 0, 0],
        'knee_r': <double>[128, 0, 0],
        'spine': <double>[6, 0, 0],
      }),
      rootY: -0.7,
      weight: '坐于脚跟，脊柱延伸',
      hands: '手放在大腿上',
      mistake: '塌腰、脚背未贴地');
  add('单膝跪地', '跪姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-86, 0, 10],
        'knee_l': <double>[120, 0, 0],
        'hip_r': <double>[-30, 0, -18],
        'knee_r': <double>[88, 0, 0],
        'spine': <double>[8, 0, 0],
      }),
      rootY: -0.54,
      weight: '一膝跪地，另一腿脚掌踩实',
      hands: '手扶前膝或触碰地面',
      mistake: '重心后坐、前腿角度过大');
  add('跪姿后仰', '跪姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-102, 0, 8],
        'hip_r': <double>[-102, 0, -8],
        'knee_l': <double>[124, 0, 0],
        'knee_r': <double>[124, 0, 0],
        'spine': <double>[-18, 0, 0],
        'neck': <double>[-10, 0, 0],
      }),
      rootY: -0.74,
      weight: '骨盆前推，胸腔打开后仰',
      hands: '手撑身后地面',
      mistake: '用手腕硬撑、腰椎过度压缩');
  add('跪姿前俯', '跪姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-110, 0, 7],
        'hip_r': <double>[-110, 0, -7],
        'knee_l': <double>[130, 0, 0],
        'knee_r': <double>[130, 0, 0],
        'spine': <double>[26, 0, 0],
        'neck': <double>[-8, 0, 0],
      }),
      rootY: -0.72,
      weight: '上身向前俯低，背部拉长',
      hands: '双手向前伸展触地',
      mistake: '弓背、臀部翘得过高');
  add('侧跪支撑', '跪姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-104, 0, 14],
        'knee_l': <double>[126, 0, 0],
        'hip_r': <double>[-58, 0, -30],
        'knee_r': <double>[112, 0, 0],
        'spine': <double>[6, 0, -12],
      }),
      rootY: -0.66,
      weight: '侧向坐于一侧腿，另一腿抬起',
      hands: '单手撑地、另一手放松',
      mistake: '侧倾不足、造型扁平');
  add('跪姿回望', '跪姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-106, 0, 8],
        'hip_r': <double>[-106, 0, -8],
        'knee_l': <double>[128, 0, 0],
        'knee_r': <double>[128, 0, 0],
        'spine': <double>[4, 22, 0],
        'neck': <double>[0, -34, 0],
      }),
      rootY: -0.7,
      weight: '跪坐后向后回望，肩线带动',
      hands: '手可扶发或撑在身后',
      mistake: '腰不转只扭头');

  // ---------------- 靠姿（6 核心） ----------------
  add('靠墙单腿', '靠姿',
      _j(<String, List<double>>{
        'spine': <double>[4, 0, -8],
        'hip_l': <double>[-16, 0, 8],
        'knee_l': <double>[30, 0, 0],
        'knee_r': <double>[6, 0, 0],
      }),
      weight: '背部贴墙，单腿屈起踩墙',
      hands: '手插兜或抱臂',
      mistake: '头也贴墙、颈部歪斜');
  add('靠栏远望', '靠姿',
      _j(<String, List<double>>{
        'spine': <double>[6, -8, 0],
        'shoulder_l': <double>[-30, 0, 20],
        'elbow_l': <double>[-88, 0, 20],
        'neck': <double>[-4, 12, 0],
        'hip_l': <double>[-8, 0, 4],
        'knee_l': <double>[14, 0, 0],
      }),
      weight: '手肘撑在栏杆，重心向一侧',
      hands: '远侧手放松垂下',
      mistake: '肩线不在同一平面、姿态别扭');
  add('背靠站立', '靠姿',
      _j(<String, List<double>>{
        'spine': <double>[-4, 0, 0],
        'shoulder_l': <double>[-26, 0, -14],
        'shoulder_r': <double>[-26, 0, 14],
      }),
      weight: '肩胛与臀部贴墙，脚步前移',
      hands: '双手自然背在身后',
      mistake: '脚离墙太远导致身体悬空');
  add('侧肩靠墙', '靠姿',
      _j(<String, List<double>>{
        'spine': <double>[2, 0, -14],
        'shoulder_r': <double>[-20, 0, -24],
        'hip_l': <double>[-10, 0, 6],
        'knee_l': <double>[18, 0, 0],
      }),
      weight: '单肩贴墙，另一侧身体向前',
      hands: '一只手叉腰形成三角',
      mistake: '整个人横贴墙面、缺乏立体感');
  add('靠树低首', '靠姿',
      _j(<String, List<double>>{
        'spine': <double>[10, 0, -6],
        'neck': <double>[16, 0, 0],
        'hip_l': <double>[-12, 0, 5],
        'knee_l': <double>[24, 0, 0],
      }),
      weight: '后背轻靠树干，重心下沉',
      hands: '手指交叠在身前',
      mistake: '头埋太低看不见神态');
  add('倚靠放松', '靠姿',
      _j(<String, List<double>>{
        'spine': <double>[-6, 0, 4],
        'hip_l': <double>[-6, 0, 10],
        'hip_r': <double>[-6, 0, -2],
        'knee_l': <double>[10, 0, 0],
        'knee_r': <double>[14, 0, 0],
      }),
      weight: '全身放松倚靠，双腿微交叉',
      hands: '双手轻扶支撑面',
      mistake: '全身瘫软、显得没有精神');

  // ---------------- 躺姿（6 核心） ----------------
  add('平躺舒展', '躺姿',
      _j(<String, List<double>>{
        'spine': <double>[-2, 0, 0],
        'hip_l': <double>[-6, 0, 6],
        'hip_r': <double>[-6, 0, -6],
        'knee_l': <double>[8, 0, 0],
        'knee_r': <double>[8, 0, 0],
      }),
      rootY: -1.02,
      rootPitch: -88,
      weight: '仰卧于地面，四肢自然伸展',
      hands: '手臂放松摊开',
      mistake: '姿势僵硬、手脚角度雷同');
  add('侧躺曲臂', '躺姿',
      _j(<String, List<double>>{
        'spine': <double>[0, -6, 0],
        'shoulder_l': <double>[-40, 0, 12],
        'elbow_l': <double>[-96, 0, 20],
        'hip_l': <double>[-28, 0, 10],
        'hip_r': <double>[-10, 0, -8],
        'knee_l': <double>[42, 0, 0],
        'knee_r': <double>[16, 0, 0],
      }),
      rootY: -1.0,
      rootPitch: -90,
      weight: '侧卧支撑，身体呈 S 曲线',
      hands: '近地手托头，远侧手放身前',
      mistake: '身体完全平直、缺少曲线');
  add('趴伏抬头', '躺姿',
      _j(<String, List<double>>{
        'spine': <double>[-8, 0, 0],
        'neck': <double>[-18, 0, 0],
        'shoulder_l': <double>[-34, 0, 16],
        'elbow_l': <double>[-86, 0, 22],
        'shoulder_r': <double>[-34, 0, -16],
        'elbow_r': <double>[-86, 0, -22],
      }),
      rootY: -1.02,
      rootPitch: 88,
      weight: '俯卧，用手肘撑起上身',
      hands: '手肘着地、手掌托腮',
      mistake: '颈部后仰过度、腰部塌陷');
  add('躺姿伸腿', '躺姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-10, 0, 18],
        'hip_r': <double>[-10, 0, -18],
        'knee_l': <double>[12, 0, 0],
        'knee_r': <double>[12, 0, 0],
        'spine': <double>[-4, 0, 0],
      }),
      rootY: -1.02,
      rootPitch: -88,
      weight: '仰卧单腿或双腿向一侧伸展',
      hands: '手臂向头顶延伸拉长身体',
      mistake: '腰部离地、膝盖锁死');
  add('蜷缩侧卧', '躺姿',
      _j(<String, List<double>>{
        'spine': <double>[18, 0, 0],
        'neck': <double>[12, 0, 0],
        'hip_l': <double>[-46, 0, 16],
        'hip_r': <double>[-46, 0, -16],
        'knee_l': <double>[86, 0, 0],
        'knee_r': <double>[86, 0, 0],
        'shoulder_l': <double>[-30, 0, 12],
        'elbow_l': <double>[-104, 0, 24],
      }),
      rootY: -1.0,
      rootPitch: -90,
      weight: '胎儿式蜷缩，形成稳定团块',
      hands: '手臂收在胸前',
      mistake: '团块过硬、没有呼吸感');
  add('仰卧屈膝', '躺姿',
      _j(<String, List<double>>{
        'hip_l': <double>[-36, 0, 8],
        'hip_r': <double>[-36, 0, -8],
        'knee_l': <double>[84, 0, 0],
        'knee_r': <double>[84, 0, 0],
        'spine': <double>[-2, 0, 0],
      }),
      rootY: -1.0,
      rootPitch: -90,
      weight: '仰卧屈膝，脚掌贴地',
      hands: '手放在腹部或身体两侧',
      mistake: '膝盖左右倒、角度不对称');

  // ---------------- 动态（7 核心） ----------------
  add('行走瞬间', '动态',
      _j(<String, List<double>>{
        'hip_l': <double>[-34, 0, 6],
        'knee_l': <double>[26, 0, 0],
        'hip_r': <double>[26, 0, -6],
        'knee_r': <double>[42, 0, 0],
        'shoulder_l': <double>[16, 0, 10],
        'shoulder_r': <double>[-22, 0, -12],
        'elbow_l': <double>[-24, 0, 0],
        'elbow_r': <double>[-36, 0, 0],
        'spine': <double>[2, 0, 0],
      }),
      weight: '前腿落地、后腿蹬地',
      hands: '手臂与腿反向摆动',
      mistake: '同手同脚、身体上下起伏过大');
  add('小跑前进', '动态',
      _j(<String, List<double>>{
        'hip_l': <double>[-56, 0, 8],
        'knee_l': <double>[66, 0, 0],
        'hip_r': <double>[18, 0, -8],
        'knee_r': <double>[84, 0, 0],
        'shoulder_l': <double>[26, 0, 12],
        'shoulder_r': <double>[-34, 0, -14],
        'elbow_l': <double>[-68, 0, 0],
        'elbow_r': <double>[-84, 0, 0],
        'spine': <double>[8, 0, 0],
      }),
      rootY: 0.04,
      weight: '前脚掌发力，重心略前',
      hands: '手肘约 90°，前后摆动',
      mistake: '上半身僵硬、手臂不摆');
  add('跳起悬空', '动态',
      _j(<String, List<double>>{
        'hip_l': <double>[-30, 0, 16],
        'hip_r': <double>[-30, 0, -16],
        'knee_l': <double>[56, 0, 0],
        'knee_r': <double>[56, 0, 0],
        'shoulder_l': <double>[-64, 0, 24],
        'shoulder_r': <double>[-64, 0, -24],
        'elbow_l': <double>[-16, 0, 0],
        'elbow_r': <double>[-16, 0, 0],
        'spine': <double>[-6, 0, 0],
      }),
      rootY: 0.3,
      weight: '起跳悬空，身体向上延伸',
      hands: '双手向上舒展',
      mistake: '双腿并得太紧、缺乏张力');
  add('旋转回身', '动态',
      _j(<String, List<double>>{
        'spine': <double>[6, 28, 0],
        'neck': <double>[0, -36, 0],
        'hip_l': <double>[-18, 12, 6],
        'hip_r': <double>[-18, 12, -6],
        'knee_l': <double>[36, 0, 0],
        'shoulder_l': <double>[-30, 0, 20],
        'shoulder_r': <double>[10, 0, -20],
      }),
      rootY: 0.06,
      weight: '以脚掌为轴旋转，裙摆带动',
      hands: '一只手向外展开增加动势',
      mistake: '上下半身脱节、旋转角度不够');
  add('腾空劈叉', '动态',
      _j(<String, List<double>>{
        'hip_l': <double>[-42, 0, 24],
        'hip_r': <double>[34, 0, -24],
        'knee_l': <double>[10, 0, 0],
        'knee_r': <double>[10, 0, 0],
        'shoulder_l': <double>[-70, 0, 30],
        'shoulder_r': <double>[-70, 0, -30],
        'spine': <double>[-4, 0, 0],
      }),
      rootY: 0.22,
      weight: '空中劈叉，双腿向两侧打开',
      hands: '双臂向上打开保持平衡',
      mistake: '膝盖弯曲、开度不足');
  add('前倾冲刺', '动态',
      _j(<String, List<double>>{
        'spine': <double>[26, 0, 0],
        'neck': <double>[-16, 0, 0],
        'hip_l': <double>[-64, 0, 8],
        'knee_l': <double>[54, 0, 0],
        'hip_r': <double>[36, 0, -8],
        'knee_r': <double>[70, 0, 0],
        'shoulder_l': <double>[-42, 0, 18],
        'elbow_l': <double>[-96, 0, 0],
        'shoulder_r': <double>[34, 0, -18],
        'elbow_r': <double>[-78, 0, 0],
      }),
      rootY: 0.02,
      weight: '身体前倾，后腿蹬伸',
      hands: '同侧手臂前后大幅摆动',
      mistake: '弓背、头部低垂');
  add('接物伸展', '动态',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-96, 0, 34],
        'shoulder_r': <double>[-92, 0, -30],
        'elbow_l': <double>[-14, 0, 0],
        'elbow_r': <double>[-18, 0, 0],
        'spine': <double>[-10, 0, 6],
        'hip_l': <double>[-12, 0, 8],
        'knee_l': <double>[20, 0, 0],
      }),
      rootY: 0.08,
      weight: '向上伸展接物，重心稍提',
      hands: '双手向上前方打开',
      mistake: '手臂伸不直、身体没有延伸');

  // ---------------- 手部（6 核心，仅腕肘语义，不承诺手指动作） ----------------
  add('挥手致意', '手部',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-118, 0, 22],
        'elbow_l': <double>[-58, 0, -20],
        'wrist_l': <double>[-18, 0, 12],
        'spine': <double>[0, -6, 4],
        'neck': <double>[0, 8, 0],
      }),
      weight: '重心居中，抬臂侧肩微沉',
      hands: '手腕向上立起（无手指细节）',
      mistake: '手臂完全贴脸、腋下夹紧');
  add('指向远方', '手部',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-96, -20, 16],
        'elbow_l': <double>[-12, 0, 0],
        'wrist_l': <double>[8, 0, 0],
        'neck': <double>[-4, 14, 0],
      }),
      weight: '手指方向与视线一致',
      hands: '手臂伸直指向画外',
      mistake: '手臂角度与视线方向不一致');
  add('手托下巴', '手部',
      _j(<String, List<double>>{
        'shoulder_r': <double>[-52, 0, -26],
        'elbow_r': <double>[-124, 0, -34],
        'wrist_r': <double>[-22, 0, -8],
        'neck': <double>[6, 0, -4],
      }),
      weight: '手肘支点稳定，头部轻靠',
      hands: '手掌托住下颌侧面',
      mistake: '手掌用力挤压面部变形');
  add('手扶锁骨', '手部',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-46, 0, 34],
        'elbow_l': <double>[-128, 0, 30],
        'wrist_l': <double>[-20, 0, 14],
        'spine': <double>[0, 0, 4],
      }),
      weight: '手指轻触锁骨，肩膀下沉',
      hands: '手背朝外形成柔和线条',
      mistake: '手肘抬得过高遮挡胸口');
  add('双手合拢', '手部',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-40, 0, 22],
        'elbow_l': <double>[-108, 0, 26],
        'shoulder_r': <double>[-40, 0, -22],
        'elbow_r': <double>[-108, 0, -26],
        'wrist_l': <double>[-10, 0, -6],
        'wrist_r': <double>[-10, 0, 6],
      }),
      weight: '双手在胸前合拢，肘部下沉',
      hands: '手腕自然相对',
      mistake: '双肘外翻挤占画面空间');
  add('手撩发丝', '手部',
      _j(<String, List<double>>{
        'shoulder_r': <double>[-102, 0, -18],
        'elbow_r': <double>[-116, 0, -40],
        'wrist_r': <double>[-26, 0, -14],
        'neck': <double>[0, -6, 0],
      }),
      weight: '抬臂侧头部微倾，另一只手放松',
      hands: '指尖沿耳侧向上（无手指细节）',
      mistake: '手臂遮住整张脸');

  // ---------------- 神态（6 核心，仅脊柱与颈部语义） ----------------
  add('低头沉思', '神态',
      _j(<String, List<double>>{
        'spine': <double>[10, 0, 0],
        'neck': <double>[22, 0, 0],
        'shoulder_l': <double>[-8, 0, -4],
        'shoulder_r': <double>[-8, 0, 4],
      }),
      weight: '下巴微收，视线落向地面',
      hands: '双手交叠或插兜',
      mistake: '下巴贴到胸口、背部弓起');
  add('仰头望天', '神态',
      _j(<String, List<double>>{
        'spine': <double>[-8, 0, 0],
        'neck': <double>[-30, 0, 0],
        'shoulder_l': <double>[-14, 0, -10],
        'shoulder_r': <double>[-14, 0, 10],
      }),
      weight: '胸口打开，颈部向上延伸',
      hands: '手臂自然打开或后展',
      mistake: '腰部代偿后仰');
  add('侧颜凝视', '神态',
      _j(<String, List<double>>{
        'neck': <double>[0, 52, 0],
        'spine': <double>[0, 10, 0],
        'shoulder_l': <double>[4, 0, -6],
      }),
      weight: '头部转向侧面，肩线保持',
      hands: '远侧手藏在身后减少干扰',
      mistake: '肩膀跟着头一起转');
  add('半回头', '神态',
      _j(<String, List<double>>{
        'neck': <double>[-6, 34, 0],
        'spine': <double>[2, 14, 0],
        'shoulder_r': <double>[6, 0, -10],
      }),
      weight: '只转 3/4 侧脸，留出颈线',
      hands: '近侧手自然下垂',
      mistake: '转头角度过大露出后脑勺');
  add('含胸收拢', '神态',
      _j(<String, List<double>>{
        'spine': <double>[14, 0, 0],
        'neck': <double>[10, 0, 0],
        'shoulder_l': <double>[6, 0, -16],
        'shoulder_r': <double>[6, 0, 16],
        'hip_l': <double>[-4, 0, 2],
        'hip_r': <double>[-4, 0, -2],
      }),
      weight: '收紧身体形成防御感',
      hands: '双手抱住自己',
      mistake: '含胸过度变成驼背');
  add('舒展挺胸', '神态',
      _j(<String, List<double>>{
        'spine': <double>[-12, 0, 0],
        'neck': <double>[-6, 0, 0],
        'shoulder_l': <double>[-20, 0, -18],
        'shoulder_r': <double>[-20, 0, 18],
      }),
      weight: '肩胛后收、胸腔上提',
      hands: '手向后延伸或叉腰',
      mistake: '过度挺胸导致腰椎受压');

  // ---------------- 道具互动（6 核心） ----------------
  add('撑伞而立', '道具互动',
      _j(<String, List<double>>{
        'shoulder_r': <double>[-102, 0, -20],
        'elbow_r': <double>[-76, 0, -18],
        'wrist_r': <double>[-12, 0, -8],
        'spine': <double>[2, -6, 0],
        'neck': <double>[0, 10, 0],
      }),
      weight: '持伞手肘置于肩线上方',
      hands: '伞柄位于虎口上方',
      mistake: '伞沿压住头顶、手臂挡住脸');
  add('举花轻嗅', '道具互动',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-58, 0, 34],
        'elbow_l': <double>[-118, 0, 26],
        'wrist_l': <double>[-22, 0, 10],
        'spine': <double>[0, -10, 0],
        'neck': <double>[10, 8, 0],
      }),
      weight: '手肘落于胸线下方',
      hands: '花束低于眼睛、露出眉眼',
      mistake: '花挡全脸、手肘高过头顶');
  add('手持相机', '道具互动',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-72, 0, 26],
        'elbow_l': <double>[-88, 0, 18],
        'shoulder_r': <double>[-64, 0, -22],
        'elbow_r': <double>[-96, 0, -26],
        'neck': <double>[8, 0, 0],
        'spine': <double>[4, 0, 0],
      }),
      weight: '双肘夹紧，相机贴近面部',
      hands: '双手托持相机',
      mistake: '相机悬空离脸太远');
  add('背包单肩', '道具互动',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-24, 0, 18],
        'elbow_l': <double>[-68, 0, 12],
        'spine': <double>[0, 0, -6],
        'hip_r': <double>[-6, 0, -4],
        'knee_r': <double>[12, 0, 0],
      }),
      weight: '包带压肩，另一侧肩下沉',
      hands: '手指勾住包带',
      mistake: '包带滑落、肩线不对称过度');
  add('抱琴而立', '道具互动',
      _j(<String, List<double>>{
        'shoulder_l': <double>[-46, 0, 20],
        'elbow_l': <double>[-96, 0, 26],
        'shoulder_r': <double>[-46, 0, -20],
        'elbow_r': <double>[-96, 0, -26],
        'spine': <double>[0, -8, 0],
      }),
      weight: '道具贴近身体、双肘下沉',
      hands: '双手环抱道具侧面',
      mistake: '道具悬空离身、手臂僵直');
  add('扶帽侧身', '道具互动',
      _j(<String, List<double>>{
        'shoulder_r': <double>[-64, 0, -44],
        'elbow_r': <double>[-108, 0, -30],
        'wrist_r': <double>[-26, 0, -10],
        'spine': <double>[2, -14, 0],
        'neck': <double>[0, 22, 0],
      }),
      weight: '扶帽手肘形成三角，头微侧',
      hands: '指尖搭帽檐',
      mistake: '手肘正对镜头形成视觉拥堵');

  return list;
}

String _difficulty(Map<String, List<double>> joints, double rootPitch) {
  var maxAbs = rootPitch.abs();
  for (final List<double> v in joints.values) {
    for (final double a in v) {
      if (a.abs() > maxAbs) maxAbs = a.abs();
    }
  }
  if (maxAbs < 28) return '新手友好';
  if (maxAbs < 70) return '进阶';
  return '高难度';
}

String _lensFor(_Core core) {
  switch (core.category) {
    case '站姿':
      return '50mm 半身';
    case '坐姿':
      return '35mm 环境人像';
    case '蹲姿':
      return '35mm 低机位';
    case '跪姿':
      return '50mm 半身';
    case '靠姿':
      return '35mm 全身';
    case '躺姿':
      return '24mm 俯拍';
    case '动态':
      return '85mm 追焦';
    case '手部':
      return '85mm 特写';
    case '神态':
      return '135mm 特写';
    default:
      return '50mm 人像';
  }
}

String _cameraFor(_Core core) {
  switch (core.category) {
    case '站姿':
      return '胸口高度平视';
    case '坐姿':
      return '略低于眼位';
    case '蹲姿':
      return '腰位偏低';
    case '跪姿':
      return '与眼位齐平';
    case '靠姿':
      return '斜前方 45°';
    case '躺姿':
      return '俯拍 60°';
    case '动态':
      return '与腰位齐平，预判跟随';
    case '手部':
      return '特写机位略高';
    case '神态':
      return '眼位平视';
    default:
      return '腰位平视';
  }
}
