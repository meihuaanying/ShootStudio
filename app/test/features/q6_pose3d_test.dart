/// V7/D141（S5）：RTMPose/RTMW3D 端上识别 —— 纯 Dart 数学层 fixture 测试（R62）。
///
/// 覆盖：crop 仿射/归一化、letterbox、simcc 解码、YOLOX 解码/NMS、133→33 映射与
/// 骨长先验尺度、分片拼装（含失败路径）。全部可离线运行（CI 常跑），真实模型一致性
/// 测试见 `q6_pose3d_consistency_test.dart`（SS_POSE_ACCURACY=1 门控）。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoot_studio/services/pose3d/pose3d_assembly.dart';
import 'package:shoot_studio/services/pose3d/pose3d_decode.dart';
import 'package:shoot_studio/services/pose3d/pose3d_geometry.dart';
import 'package:shoot_studio/services/pose3d/pose3d_mapping.dart';

/// 构造 32×32 RGBA 测试图：`r=x*8, g=y*8, b=255-x*8`。
Uint8List _image32() {
  final Uint8List rgba = Uint8List(32 * 32 * 4);
  for (int y = 0; y < 32; y++) {
    for (int x = 0; x < 32; x++) {
      final int i = (y * 32 + x) * 4;
      rgba[i] = x * 8;
      rgba[i + 1] = y * 8;
      rgba[i + 2] = 255 - x * 8;
      rgba[i + 3] = 255;
    }
  }
  return rgba;
}

double _norm(int channel, int value) =>
    (value - kPose3dMean[channel]) / kPose3dStd[channel];

void main() {
  group('Q6 pose3d 几何（D141）', () {
    test('Pose3dCropSpec.fromBox：1.25 padding + 3:4 扩展 + 仿射尺度', () {
      final Pose3dCropSpec a = Pose3dCropSpec.fromBox(
        const Pose3dBox(100, 200, 300, 600),
      );
      expect(a.centerX, 200);
      expect(a.centerY, 400);
      // bw=250, bh=500 → bh*0.75=375 > bw → scaleW=375
      expect(a.scaleW, 375);
      expect(a.affineScale, closeTo(288 / 375, 1e-12));
      final Pose3dCropSpec b = Pose3dCropSpec.fromBox(
        const Pose3dBox(0, 0, 400, 400),
      );
      // bw=500 > bh*0.75=375 → scaleW=500
      expect(b.scaleW, 500);
      expect(b.centerX, 200);
    });

    test('warp：恒等映射（center=(144,192)、scaleW=288）仅 BGR+归一化', () {
      final Uint8List rgba = _image32();
      const Pose3dCropSpec spec = Pose3dCropSpec(
        centerX: 16,
        centerY: 16,
        scaleW: 32,
        outW: 32,
        outH: 32,
      );
      final Float32List t = warpCropBgrNormalized(rgba, 32, 32, spec);
      const int plane = 32 * 32;
      for (final (int x, int y) in <(int, int)>[(0, 0), (5, 7), (31, 31)]) {
        final int idx = y * 32 + x;
        expect(t[idx], closeTo(_norm(0, 255 - x * 8), 1e-6)); // B
        expect(t[plane + idx], closeTo(_norm(1, y * 8), 1e-6)); // G
        expect(t[2 * plane + idx], closeTo(_norm(2, x * 8), 1e-6)); // R
      }
    });

    test('warp：缩放映射（scaleW=32 → out 16，src=2*dst-16）', () {
      final Uint8List rgba = _image32();
      const Pose3dCropSpec spec = Pose3dCropSpec(
        centerX: 0,
        centerY: 0,
        scaleW: 32,
        outW: 16,
        outH: 16,
      );
      final Float32List t = warpCropBgrNormalized(rgba, 32, 32, spec);
      const int plane = 16 * 16;
      // dst(8,8) → src(0,0)
      expect(t[8 * 16 + 8], closeTo(_norm(0, 255), 1e-6));
      expect(t[plane + 8 * 16 + 8], closeTo(_norm(1, 0), 1e-6));
      expect(t[2 * plane + 8 * 16 + 8], closeTo(_norm(2, 0), 1e-6));
      // dst(0,0) → src(-16,-16) 越界 → 0 → (0-mean)/std
      expect(t[0], closeTo(_norm(0, 0), 1e-6));
      expect(t[plane], closeTo(_norm(1, 0), 1e-6));
    });

    test('letterbox：同尺寸恒等（无归一化、BGR、pad=114）', () {
      final Uint8List rgba = _image32();
      final Pose3dLetterbox lb = letterboxChw(rgba, 32, 32, 32, 32);
      expect(lb.ratio, 1);
      const int plane = 32 * 32;
      expect(lb.tensor[5 * 32 + 7], closeTo(255 - 7 * 8, 1e-6)); // B
      expect(lb.tensor[plane + 5 * 32 + 7], closeTo(5 * 8, 1e-6)); // G
      expect(lb.tensor[2 * plane + 5 * 32 + 7], closeTo(7 * 8, 1e-6)); // R
    });

    test('letterbox：宽图上下填 pad；缩小图半像素中心采样', () {
      final Uint8List rgba = _image32();
      // 32×16 → 32×32：ratio=min(2,1)=1 → 下半 pad
      final Pose3dLetterbox lb = letterboxChw(rgba, 32, 16, 32, 32);
      expect(lb.ratio, 1);
      const int plane = 32 * 32;
      expect(lb.tensor[20 * 32 + 3], 114);
      expect(lb.tensor[plane + 20 * 32 + 3], 114);
      expect(lb.tensor[2 * plane + 20 * 32 + 3], 114);
      // 64×64 → 32×32：ratio=0.5 → fx=(x+0.5)*2-0.5=2x+0.5
      final Uint8List big = Uint8List(64 * 64 * 4);
      for (int y = 0; y < 64; y++) {
        for (int x = 0; x < 64; x++) {
          final int i = (y * 64 + x) * 4;
          big[i] = 10;
          big[i + 1] = 20;
          big[i + 2] = 30;
          big[i + 3] = 255;
        }
      }
      final Pose3dLetterbox lb2 = letterboxChw(big, 64, 64, 32, 32);
      expect(lb2.ratio, 0.5);
      expect(lb2.tensor[0], closeTo(30, 1e-6)); // B
      expect(lb2.tensor[plane], closeTo(20, 1e-6)); // G
      expect(lb2.tensor[2 * plane], closeTo(10, 1e-6)); // R
    });
  });

  group('Q6 pose3d 解码（D141）', () {
    test('decodeSimcc3d：argmax/2、z 换算、2D 重投影、零值无效', () {
      const int k = 2;
      const int wx = 4;
      const int wy = 6;
      const int wz = 8;
      final Float32List sx = Float32List(k * wx)..fillRange(0, k * wx, 1);
      final Float32List sy = Float32List(k * wy)..fillRange(0, k * wy, 1);
      final Float32List sz = Float32List(k * wz)..fillRange(0, k * wz, 1);
      sx[0 * wx + 2] = 5; // key0 x argmax=2 → kx=1.0
      sy[0 * wy + 4] = 7; // key0 y argmax=4 → ky=2.0
      sz[0 * wz + 3] = 3; // key0 z argmax=3 → kz=1.5
      // key1 全 0 → 无效
      sx.fillRange(wx, 2 * wx, 0);
      sy.fillRange(wy, 2 * wy, 0);
      sz.fillRange(wz, 2 * wz, 0);
      final Pose3dKeypoints kp = decodeSimcc3d(
        simccX: sx,
        simccY: sy,
        simccZ: sz,
        numKeypoints: k,
        simccW: wx,
        simccH: wy,
        simccZLen: wz,
        spec: const Pose3dCropSpec(
          centerX: 100,
          centerY: 100,
          scaleW: 200,
          outW: 288,
          outH: 384,
        ),
      );
      expect(kp.scores[0], 5);
      expect(kp.x[0], closeTo(1.0, 1e-6));
      expect(kp.y[0], closeTo(2.0, 1e-6));
      expect(kp.z[0], closeTo((1.5 / 192 - 1) * 2.1744869, 1e-6));
      expect(kp.x2d[0], closeTo(1.0 / 288 * 200 + 100 - 100, 1e-6));
      expect(
        kp.y2d[0],
        closeTo(
          2.0 / 384 * (200 * 384 / 288) + 100 - 0.5 * (200 * 384 / 288),
          1e-6,
        ),
      );
      expect(kp.scores[1], 0);
      expect(kp.x[1], -1);
      expect(kp.y[1], -1);
      expect(kp.z[1], -1);
      expect(kp.x2d[1], -1);
    });

    test('decodeYolox：anchor-free 解码 + 阈值', () {
      const int inH = 64;
      const int inW = 64;
      const int rows = 64 + 16 + 4; // strides 8/16/32
      const int cols = 85;
      final Float32List out = Float32List(rows * cols);
      // row0 = grid(0,0) stride8：cx=0, cy=0, w=exp(0)*8=8, h=8, obj=1, cls0=0.9
      out[0 * cols + 0] = 0;
      out[0 * cols + 1] = 0;
      out[0 * cols + 2] = 0;
      out[0 * cols + 3] = 0;
      out[0 * cols + 4] = 1;
      out[0 * cols + 5] = 0.9;
      final List<Pose3dDetection> dets = decodeYolox(
        output: out,
        rows: rows,
        cols: cols,
        inH: inH,
        inW: inW,
        ratio: 1,
      );
      expect(dets.length, 1);
      expect(dets.first.classId, 0);
      expect(dets.first.score, closeTo(0.9, 1e-6));
      expect(dets.first.box.x1, closeTo(-4, 1e-6));
      expect(dets.first.box.y2, closeTo(4, 1e-6));
    });

    test('decodeYolox：同框 NMS 抑制（同类）/ 异类保留', () {
      const int inH = 64;
      const int inW = 64;
      const int rows = 64 + 16 + 4;
      const int cols = 85;
      final Float32List out = Float32List(rows * cols);
      // row0 grid(0,0) 与 row1 grid(1,0) 产生相同框（tx=-1 抵消）
      void setRow(int row, double tx, double clsScore, int clsIdx) {
        final int b = row * cols;
        out[b] = tx;
        out[b + 1] = 0;
        out[b + 2] = 0;
        out[b + 3] = 0;
        out[b + 4] = 1;
        out[b + 5 + clsIdx] = clsScore;
      }

      setRow(0, 0, 0.9, 0);
      setRow(1, -1, 0.8, 0);
      List<Pose3dDetection> dets = decodeYolox(
        output: out,
        rows: rows,
        cols: cols,
        inH: inH,
        inW: inW,
        ratio: 1,
      );
      expect(dets.length, 1);
      expect(dets.first.score, closeTo(0.9, 1e-6));
      // 不同类 → 都保留
      setRow(1, -1, 0.8, 1);
      dets = decodeYolox(
        output: out,
        rows: rows,
        cols: cols,
        inH: inH,
        inW: inW,
        ratio: 1,
      );
      expect(dets.length, 2);
    });
  });

  group('Q6 pose3d 映射（D141）', () {
    test('scaleFromBones：一致骨长 → 中位数尺度；无效骨跳过', () {
      const double s = 0.005;
      final Float32List x = Float32List(133);
      final Float32List y = Float32List(133);
      final Float32List z = Float32List(133);
      final Float32List sc = Float32List(133);
      for (final (int a, int b, double prior) in kPose3dBones) {
        final double d = prior / s;
        x[b] = x[a] + d;
        sc[a] = 0.9;
        sc[b] = 0.9;
      }
      final Pose3dKeypoints kp = Pose3dKeypoints(
        count: 133,
        x: x,
        y: y,
        z: z,
        scores: sc,
        x2d: Float32List(133),
        y2d: Float32List(133),
      );
      final ({double scale, int bonesUsed}) r = scaleFromBones(kp);
      expect(r.bonesUsed, kPose3dBones.length);
      expect(r.scale, closeTo(s, 1e-9));
    });

    test('toWorld33：髋中心化、y 向下、置信度与未映射点', () {
      final Float32List x = Float32List(133);
      final Float32List y = Float32List(133);
      final Float32List z = Float32List(133);
      final Float32List sc = Float32List(133);
      for (final (int a, int b, double prior) in kPose3dBones) {
        x[b] = x[a] + prior / 0.005;
        sc[a] = 0.8;
      }
      // 髋点抬升（y 向下：y 越大越靠下）；左踝在髋下方
      y[23] = 500;
      y[24] = 500;
      y[15] = 900;
      final Pose3dWorld33 w = toWorld33(
        Pose3dKeypoints(
          count: 133,
          x: x,
          y: y,
          z: z,
          scores: sc,
          x2d: Float32List(133),
          y2d: Float32List(133),
        ),
      );
      expect(w.bonesUsed, kPose3dBones.length);
      // 髋中心 → 0
      expect((w.world[23][0] + w.world[24][0]) / 2, closeTo(0, 1e-9));
      expect((w.world[23][1] + w.world[24][1]) / 2, closeTo(0, 1e-9));
      // y 向下：左踝（BlazePose 27 ← RTMW 15，kp.y=900）在髋（500）下方 → world y > 0
      expect(w.world[27][1], greaterThan(0));
      expect(w.world[23][1], closeTo(0, 1e-9));
      // 置信度映射与未映射点（world 为 0-髋中心，置信度 0）
      expect(w.confidence[23], closeTo(0.8, 1e-6));
      expect(w.confidence[1], 0);
      // 髋中心 x=(x11+x12)/2*s=(0+65)/2*0.005=0.1625 → 未映射点 = -0.1625
      expect(w.world[1][0], closeTo(-0.1625, 1e-6));
    });
  });

  group('Q6 pose3d 分片拼装（D141 / R64）', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('ss_pose3d_');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('拼装 → 复用 → 摘要校验 → 失败清理', () async {
      final List<int> partA = <int>[1, 2, 3];
      final List<int> partB = <int>[4, 5, 6];
      final List<int> all = <int>[...partA, ...partB];
      final String sha = sha256.convert(all).toString();
      final Pose3dAssemblySpec spec = Pose3dAssemblySpec(
        parts: <Pose3dPartSpec>[
          Pose3dPartSpec(assetKey: 'a', bytes: partA.length),
          Pose3dPartSpec(assetKey: 'b', bytes: partB.length),
        ],
        totalBytes: all.length,
        sha256: sha,
      );
      final File target = File(
        '${dir.path}${Platform.pathSeparator}model.onnx',
      );
      final Map<String, Uint8List> store = <String, Uint8List>{
        'a': Uint8List.fromList(partA),
        'b': Uint8List.fromList(partB),
      };
      Pose3dAssembledModel r = await ensurePose3dModel(
        spec: spec,
        target: target,
        readAsset: (String key) async => store[key]!,
      );
      expect(r.reused, false);
      expect(r.bytes, 6);
      expect(await target.readAsBytes(), all);
      // 复用
      r = await ensurePose3dModel(
        spec: spec,
        target: target,
        readAsset: (String key) async => throw StateError('不应读取分片'),
      );
      expect(r.reused, true);
      // 摘要不符（内容被篡改）→ 重新拼装
      await target.writeAsBytes(<int>[9, 9, 9, 9, 9, 9]);
      r = await ensurePose3dModel(
        spec: spec,
        target: target,
        readAsset: (String key) async => store[key]!,
      );
      expect(r.reused, false);
      expect(await target.readAsBytes(), all);
      // 分片大小不符 → 异常 + 无残留（用独立目标文件，避免命中复用）
      final Pose3dAssemblySpec bad = Pose3dAssemblySpec(
        parts: <Pose3dPartSpec>[
          Pose3dPartSpec(assetKey: 'a', bytes: 99),
          Pose3dPartSpec(assetKey: 'b', bytes: partB.length),
        ],
        totalBytes: all.length,
        sha256: sha,
      );
      final File target2 = File(
        '${dir.path}${Platform.pathSeparator}model2.onnx',
      );
      await expectLater(
        ensurePose3dModel(
          spec: bad,
          target: target2,
          readAsset: (String key) async => store[key]!,
        ),
        throwsA(isA<Pose3dAssemblyException>()),
      );
      expect(File('${target2.path}.tmp').existsSync(), false);
      expect(target2.existsSync(), false);
    });
  });
}
