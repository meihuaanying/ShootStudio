/// BlazePose world landmarks → 引擎 12 关节角（V4 / R20）。
///
/// 忠实移植 `tool/skeleton_to_joints.py`（同一坐标系约定与关节限位），
/// 供端上 `pose_detection`（Windows/Android）识别用户导入照片时推导姿势；
/// 构建期内置姿势仍由 Python 管线产出，二者口径一致（见 q2 测试的等价性断言）。
///
/// 坐标系：人物面向 +Z；关节角为 Three.js Euler 'XYZ'（度）。
library;

import 'dart:math' as math;

typedef V3 = List<double>;

V3 v3(double x, double y, double z) => <double>[x, y, z];

double _dot(V3 a, V3 b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

V3 _cross(V3 a, V3 b) => <double>[
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];

V3 _sub(V3 a, V3 b) => <double>[a[0] - b[0], a[1] - b[1], a[2] - b[2]];

V3 _add(V3 a, V3 b) => <double>[a[0] + b[0], a[1] + b[1], a[2] + b[2]];

V3 _scale(V3 a, double s) => <double>[a[0] * s, a[1] * s, a[2] * s];

double _norm(V3 a) => math.sqrt(_dot(a, a));

V3 unit(V3 a) {
  final double n = _norm(a);
  return n > 1e-9 ? _scale(a, 1.0 / n) : v3(0, 0, 0);
}

typedef Mat3 = List<List<double>>;

/// Three.js Euler 'XYZ'：R = Rx·Ry·Rz（角度制）。
Mat3 eulerXyz(double rx, double ry, double rz) {
  final double ax = rx * math.pi / 180;
  final double ay = ry * math.pi / 180;
  final double az = rz * math.pi / 180;
  final double cx = math.cos(ax), sx = math.sin(ax);
  final double cy = math.cos(ay), sy = math.sin(ay);
  final double cz = math.cos(az), sz = math.sin(az);
  return <List<double>>[
    <double>[cy * cz, -cy * sz, sy],
    <double>[sx * sy * cz + cx * sz, cx * cz - sx * sy * sz, -sx * cy],
    <double>[sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy],
  ];
}

Mat3 _matMul(Mat3 a, Mat3 b) {
  final Mat3 out = List<List<double>>.generate(
    3,
    (_) => List<double>.filled(3, 0),
  );
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      double sum = 0;
      for (int k = 0; k < 3; k++) {
        sum += a[i][k] * b[k][j];
      }
      out[i][j] = sum;
    }
  }
  return out;
}

Mat3 matT(Mat3 a) => <List<double>>[
  <double>[a[0][0], a[1][0], a[2][0]],
  <double>[a[0][1], a[1][1], a[2][1]],
  <double>[a[0][2], a[1][2], a[2][2]],
];

V3 matVec(Mat3 a, V3 v) => <double>[
  a[0][0] * v[0] + a[0][1] * v[1] + a[0][2] * v[2],
  a[1][0] * v[0] + a[1][1] * v[1] + a[1][2] * v[2],
  a[2][0] * v[0] + a[2][1] * v[1] + a[2][2] * v[2],
];

Mat3 _columnStack(V3 c0, V3 c1, V3 c2) => <List<double>>[
  <double>[c0[0], c1[0], c2[0]],
  <double>[c0[1], c1[1], c2[1]],
  <double>[c0[2], c1[2], c2[2]],
];

/// 由旋转矩阵反解 Euler XYZ（度）；gimbal lock 时 rz=0。
List<double> eulerFromMatrix(Mat3 r) {
  final double sy = r[0][2].clamp(-1.0, 1.0);
  final double ry = math.asin(sy) * 180 / math.pi;
  double rx;
  double rz;
  if (sy.abs() < 0.999999) {
    rx = math.atan2(-r[1][2], r[2][2]) * 180 / math.pi;
    rz = math.atan2(-r[0][1], r[0][0]) * 180 / math.pi;
  } else if (sy > 0) {
    rx = math.atan2(r[1][0], r[1][1]) * 180 / math.pi;
    rz = 0;
  } else {
    rx = -math.atan2(r[1][0], r[1][1]) * 180 / math.pi;
    rz = 0;
  }
  return <double>[rx, ry, rz];
}

/// 最小扭转解：求 [rx,0,rz] 使 R·(0,-1,0)=b（b 为单位向量）。
List<double> solveDown(V3 b) {
  final double x = b[0].clamp(-1.0, 1.0);
  final double rz = math.asin(x) * 180 / math.pi;
  final double cz = math.sqrt(math.max(0, 1 - x * x));
  final double rx = cz < 1e-6 ? 0 : math.atan2(-b[2], -b[1]) * 180 / math.pi;
  return <double>[rx, 0, rz];
}

Mat3 rotY(double deg) {
  final double a = deg * math.pi / 180;
  final double c = math.cos(a), s = math.sin(a);
  return <List<double>>[
    <double>[c, 0, s],
    <double>[0, 1, 0],
    <double>[-s, 0, c],
  ];
}

/// 各关节三轴限位（未列出的轴为 ±180）；与 Python 管线一致。
const Map<String, Map<int, (double, double)>> jointLimits =
    <String, Map<int, (double, double)>>{
      'shoulder': <int, (double, double)>{
        0: (-180.0, 180.0),
        1: (-180.0, 180.0),
        2: (-90.0, 90.0),
      },
      'elbow': <int, (double, double)>{
        0: (-150.0, 5.0),
        1: (-180.0, 180.0),
        2: (-180.0, 180.0),
      },
      'hip': <int, (double, double)>{
        0: (-120.0, 40.0),
        1: (-180.0, 180.0),
        2: (-180.0, 180.0),
      },
      'knee': <int, (double, double)>{
        0: (0.0, 140.0),
        1: (-180.0, 180.0),
        2: (-180.0, 180.0),
      },
    };

const double genericLimit = 180.0;

double _limitPenalty(List<double> angles, Map<int, (double, double)> limits) {
  double penalty = 0;
  limits.forEach((int idx, (double, double) range) {
    final double v = angles[idx];
    if (v < range.$1) {
      penalty += range.$1 - v;
    } else if (v > range.$2) {
      penalty += v - range.$2;
    }
  });
  return penalty;
}

double _limbCost(
  List<double> parent,
  List<double> child,
  String parentName,
  String childName,
) {
  double cost = 25.0 * _limitPenalty(parent, jointLimits[parentName]!);
  cost += _limitPenalty(child, jointLimits[childName]!);
  cost += 0.02 * (child[2].abs() + parent[0].abs() + parent[1].abs());
  return cost;
}

/// 父子两段肢体的双关节解（肩/肘、髋/膝）。
///
/// 扫描沿骨轴的扭转自由度 φ，选「关节限位代价最小」的解，
/// 使肘/膝成为单轴铰链； flexionSign：肘 = -1、膝 = +1。
({List<double> parent, List<double> child}) solveLimb(
  V3 prox,
  V3 dist,
  String parentName,
  String childName,
  double flexionSign,
) {
  final V3 u = unit(prox);
  final V3 f = unit(dist);
  final V3 axis = _cross(u, f);
  final double n = _norm(axis);
  if (n < 1e-6) {
    return (parent: solveDown(u), child: <double>[0, 0, 0]);
  }
  final V3 h = _scale(axis, (1.0 / n) * (flexionSign > 0 ? 1 : -1));
  final V3 yAxis = _scale(u, -1);
  final Mat3 r0 = _columnStack(h, yAxis, _cross(h, yAxis));

  double bestCost = double.infinity;
  List<double> bestParent = <double>[0, 0, 0];
  List<double> bestChild = <double>[0, 0, 0];
  for (int step = 0; step < 360; step += 2) {
    final double phi = -180.0 + step;
    final Mat3 r = _matMul(r0, rotY(phi));
    final List<double> parent = eulerFromMatrix(r);
    final List<double> child = solveDown(matVec(matT(r), f));
    final double cost = _limbCost(parent, child, parentName, childName);
    if (cost < bestCost) {
      bestCost = cost;
      bestParent = parent;
      bestChild = child;
    }
  }
  for (int step = 0; step < 360; step++) {
    final double phi = -180.0 + step;
    final Mat3 r = _matMul(r0, rotY(phi));
    final List<double> parent = eulerFromMatrix(r);
    final List<double> child = solveDown(matVec(matT(r), f));
    final double cost = _limbCost(parent, child, parentName, childName);
    if (cost < bestCost - 1e-9) {
      bestCost = cost;
      bestParent = parent;
      bestChild = child;
    }
  }
  return (parent: bestParent, child: bestChild);
}

/// 由 (up, front) 两方向反解 Euler XYZ（头部/颈部）。
List<double> solveUp(V3 dirUp, V3 dirFront) {
  final V3 u = unit(dirUp);
  V3 f = _sub(dirFront, _scale(u, _dot(dirFront, u)));
  if (_norm(f) < 1e-6) {
    const V3 z = <double>[0, 0, 1];
    f = _sub(z, _scale(u, _dot(z, u)));
  }
  f = unit(f);
  final V3 left = _cross(u, f);
  final Mat3 r = _columnStack(left, u, f);
  final double sy = r[0][2].clamp(-1.0, 1.0);
  return <double>[
    math.atan2(-r[1][2], r[2][2]) * 180 / math.pi,
    math.asin(sy) * 180 / math.pi,
    math.atan2(-r[0][1], r[0][0]) * 180 / math.pi,
  ];
}

const double engineHipHeight = 0.96;
const double rootYMin = -1.15;
const double rootYMax = 0.6;

const int iNose = 0;
const int iLEar = 7;
const int iREar = 8;
const int iLSho = 11;
const int iRSho = 12;
const int iLElb = 13;
const int iRElb = 14;
const int iLWri = 15;
const int iRWri = 16;
const int iLIndex = 19;
const int iRIndex = 20;
const int iLHip = 23;
const int iRHip = 24;
const int iLKne = 25;
const int iRKne = 26;
const int iLAnk = 27;
const int iRAnk = 28;

Map<String, int> _landmarkIndex = <String, int>{
  'l_sho': iLSho,
  'r_sho': iRSho,
  'l_elb': iLElb,
  'r_elb': iRElb,
  'l_wri': iLWri,
  'r_wri': iRWri,
  'l_index': iLIndex,
  'r_index': iRIndex,
  'l_hip': iLHip,
  'r_hip': iRHip,
  'l_kne': iLKne,
  'r_kne': iRKne,
  'l_ank': iLAnk,
  'r_ank': iRAnk,
  'l_ear': iLEar,
  'r_ear': iREar,
  'nose': iNose,
};

/// 12 关节名（引擎口径，顺序固定）。
const List<String> engineJoints = <String>[
  'spine',
  'neck',
  'shoulder_l',
  'elbow_l',
  'wrist_l',
  'shoulder_r',
  'elbow_r',
  'wrist_r',
  'hip_l',
  'knee_l',
  'hip_r',
  'knee_r',
];

/// 关节推导结果。
class DerivedPose {
  const DerivedPose({
    required this.joints,
    required this.rootY,
    required this.rootPitch,
  });

  final Map<String, List<double>> joints;
  final double rootY;
  final double rootPitch;

  Map<String, Object?> toJson() => <String, Object?>{
    for (final String joint in engineJoints) joint: joints[joint],
    'rootY': rootY,
    'rootPitch': rootPitch,
  };
}

/// 核心推导：world landmarks（33 点，米制，hip 中心）→ 12 关节角。
///
/// [world] 每点形如 [x, y, z]；[category] 用于躺姿的 rootPitch 收敛（可空）。
DerivedPose deriveJoints(List<V3> world, {String category = ''}) {
  if (world.length < 33) {
    throw ArgumentError('world landmarks 不足 33 点（实际 ${world.length}）');
  }
  V3 p(String key) => world[_landmarkIndex[key]!];

  final V3 hipL = p('l_hip'), hipR = p('r_hip');
  final V3 shoL = p('l_sho'), shoR = p('r_sho');
  final V3 hipC = _scale(_add(hipL, hipR), 0.5);
  final V3 shoC = _scale(_add(shoL, shoR), 0.5);

  V3 left = unit(_sub(hipL, hipR));
  V3 up = unit(_sub(shoC, hipC));
  up = unit(_sub(up, _scale(left, _dot(up, left))));
  final V3 front = unit(_cross(left, up));

  V3 toBody(V3 v) => v3(_dot(v, left), _dot(v, up), _dot(v, front));

  // 躯干扭转（肩线相对髋线绕躯干轴）。
  final V3 shoulderLine = unit(_sub(p('l_sho'), p('r_sho')));
  final double twist =
      math.atan2(
        _dot(_cross(left, shoulderLine), up),
        _dot(left, shoulderLine),
      ) *
      180 /
      math.pi;
  final Mat3 rSpine = eulerXyz(0, twist, 0);

  final Map<String, List<double>> joints = <String, List<double>>{
    'spine': <double>[0, double.parse(twist.toStringAsFixed(2)), 0],
  };

  for (final (String side, String aSho, String aElb, String aWri, String aIdx)
      in <(String, String, String, String, String)>[
        ('l', 'l_sho', 'l_elb', 'l_wri', 'l_index'),
        ('r', 'r_sho', 'r_elb', 'r_wri', 'r_index'),
      ]) {
    final V3 upper = toBody(unit(_sub(p(aElb), p(aSho))));
    final V3 fore = toBody(unit(_sub(p(aWri), p(aElb))));
    V3 handDir = toBody(unit(_sub(p(aIdx), p(aWri))));
    if (_norm(handDir) < 1e-9) handDir = fore;
    final V3 bLocal = matVec(matT(rSpine), upper);
    final V3 cLocal = matVec(matT(rSpine), fore);
    final solved = solveLimb(bLocal, cLocal, 'shoulder', 'elbow', -1.0);
    final Mat3 rSho = eulerXyz(
      solved.parent[0],
      solved.parent[1],
      solved.parent[2],
    );
    final Mat3 rElb = eulerXyz(
      solved.child[0],
      solved.child[1],
      solved.child[2],
    );
    final V3 wLocal = matVec(matT(_matMul(rSho, rElb)), handDir);
    joints['shoulder_$side'] = solved.parent;
    joints['elbow_$side'] = solved.child;
    joints['wrist_$side'] = solveDown(wLocal);
  }

  for (final (String side, String aHip, String aKne, String aAnk)
      in <(String, String, String, String)>[
        ('l', 'l_hip', 'l_kne', 'l_ank'),
        ('r', 'r_hip', 'r_kne', 'r_ank'),
      ]) {
    final V3 thigh = toBody(unit(_sub(p(aKne), p(aHip))));
    final V3 shin = toBody(unit(_sub(p(aAnk), p(aKne))));
    final solved = solveLimb(thigh, shin, 'hip', 'knee', 1.0);
    joints['hip_$side'] = solved.parent;
    joints['knee_$side'] = solved.child;
  }

  final V3 earMid = _scale(_add(p('l_ear'), p('r_ear')), 0.5);
  final V3 headUp = toBody(unit(_sub(earMid, shoC)));
  final V3 headFront = toBody(unit(_sub(p('nose'), earMid)));
  joints['neck'] = solveUp(headUp, headFront);

  // rootPitch / rootY（与 Python 管线一致）。
  const V3 worldUp = <double>[0, -1, 0];
  final double wu = _dot(worldUp, up);
  final double wf = _dot(worldUp, front);
  final double faceUp = _dot(unit(_sub(p('nose'), earMid)), worldUp);
  double rootPitch;
  if (category == '躺姿') {
    rootPitch = faceUp >= 0 ? -88.0 : 88.0;
  } else {
    rootPitch = math.atan2(-wf, wu) * 180 / math.pi;
    rootPitch = rootPitch.clamp(-90.0, 90.0);
  }

  double lowestY = world[0][1];
  for (final V3 pt in world) {
    if (pt[1] > lowestY) lowestY = pt[1];
  }
  double rootY = (lowestY - hipC[1]) - engineHipHeight;
  rootY = rootY.clamp(rootYMin, rootYMax);

  final Map<String, List<double>> clean = <String, List<double>>{};
  for (final String name in engineJoints) {
    clean[name] = clampJoint(name, joints[name]!);
  }
  return DerivedPose(joints: clean, rootY: rootY, rootPitch: rootPitch);
}

/// 关节限位夹取（elbow rx∈[-150,5]、knee rx∈[0,140]、hip rx∈[-120,40]、
/// shoulder rz∈[-90,90]，其余 ±180）。
List<double> clampJoint(String name, List<double> angles) {
  const Map<String, int> axes = <String, int>{'rx': 0, 'ry': 1, 'rz': 2};
  final String base = name.split('_').first;
  final List<double> out = List<double>.of(angles);
  axes.forEach((String axis, int idx) {
    double lo = -genericLimit;
    double hi = genericLimit;
    final (double, double)? range = jointLimits[base]?[idx];
    if (range != null) {
      lo = range.$1;
      hi = range.$2;
    }
    final double val = out[idx];
    if (val < lo) {
      out[idx] = lo;
    } else if (val > hi) {
      out[idx] = hi;
    }
  });
  return <double>[
    double.parse(out[0].toStringAsFixed(2)),
    double.parse(out[1].toStringAsFixed(2)),
    double.parse(out[2].toStringAsFixed(2)),
  ];
}
