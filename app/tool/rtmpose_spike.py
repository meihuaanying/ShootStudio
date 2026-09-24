"""V7/S5 spike (R67): RTMPose/RTMW3D ONNX route feasibility for ShootStudio.

Checks, in order: model source/license, download channel, ONNX IO specs,
detect+3D inference on the bundled pose photos, joint-angle comparison against
the shipped MediaPipe-derived poses3.json, detector options, quantization
(dynamic/static int8) and fp16 conversion, and per-EP latency (CPU always,
DirectML when `onnxruntime-directml` is installed).

Usage (from app/):
  python tool/rtmpose_spike.py fetch
  python tool/rtmpose_spike.py specs
  python tool/rtmpose_spike.py infer --ids p001,p013
  python tool/rtmpose_spike.py compare --ids p001,p013,p025,p037
  python tool/rtmpose_spike.py detcompare
  python tool/rtmpose_spike.py quantize
  python tool/rtmpose_spike.py bench
  python tool/rtmpose_spike.py split   # GitHub 100MiB 限制：fp16 分片随包可行性

Models are staged outside the repo (default staging: %TEMP%/opencode/s5-models,
override with --stage). Only JSON evidence is written (default --out docs/qa).
"""
import argparse
import json
import os
import statistics
import sys
import time
import urllib.request

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import skeleton_to_joints as s2j  # noqa: E402

APP = os.path.dirname(HERE)
POSE_DIR = os.path.join(APP, 'assets', 'content', 'poses3')
PHOTOS = os.path.join(POSE_DIR, 'photos')
POSES3 = os.path.join(POSE_DIR, 'poses3.json')
DEFAULT_STAGE = os.path.join(os.environ.get('TEMP', '/tmp'), 'opencode', 's5-models')
DEFAULT_OUT = os.path.join(os.path.dirname(APP), 'docs', 'qa')

MIRROR = 'https://hf-mirror.com'
MODELS = {
    'rtmw3d-x.onnx': (MIRROR + '/Soykaf/RTMW3D-x/resolve/main/onnx/rtmw3d-x_8xb64_cocktail14-384x288-b0a0eab7_20240626.onnx',
                      'Soykaf/RTMW3D-x', 'apache-2.0', 369330857),
    'yolox_m.onnx': (MIRROR + '/hr16/yolox-onnx/resolve/main/yolox_m.onnx', 'hr16/yolox-onnx', 'apache-2.0', 101259744),
    'yolox_s.onnx': (MIRROR + '/hr16/yolox-onnx/resolve/main/yolox_s.onnx', 'hr16/yolox-onnx', 'apache-2.0', 35858002),
    'yolox_tiny.onnx': (MIRROR + '/hr16/yolox-onnx/resolve/main/yolox_tiny.onnx', 'hr16/yolox-onnx', 'apache-2.0', 20219662),
    'yolox_nano.onnx': (MIRROR + '/hr16/yolox-onnx/resolve/main/yolox_nano.onnx', 'hr16/yolox-onnx', 'apache-2.0', 3659407),
}
# RTMW3D 133-keypoint index -> BlazePose 33 index (subset used by derive()).
MAP33 = {
    0: 0, 7: 3, 8: 4, 11: 5, 12: 6, 13: 7, 14: 8, 15: 9, 16: 10,
    19: 99, 20: 120, 23: 11, 24: 12, 25: 13, 26: 14, 27: 15, 28: 16,
    29: 19, 30: 22, 31: 17, 32: 20,
}
# Anthropometric priors (m) for the metric scale estimate, bone pairs in 133-space.
BONES = [
    (5, 7, 0.316), (7, 9, 0.248), (6, 8, 0.316), (8, 10, 0.248),
    (11, 13, 0.417), (13, 15, 0.418), (12, 14, 0.417), (14, 16, 0.418),
    (5, 6, 0.440), (11, 12, 0.325),
]
JOINTS = ['spine', 'neck', 'shoulder_l', 'elbow_l', 'wrist_l', 'shoulder_r',
          'elbow_r', 'wrist_r', 'hip_l', 'knee_l', 'hip_r', 'knee_r']
DETECT_IMAGES = ['p001', 'p013', 'p025', 'p050', 'p085', 'p099']
COMPARE_IMAGES = ['p001', 'p013', 'p025', 'p037']
CONSISTENCY_IMAGES = ['p001', 'p013', 'p025', 'p037', 'p050', 'p085', 'p099', 'p108']


def fetch_one(url, path, expect_bytes=None):
    if os.path.exists(path) and (expect_bytes is None or os.path.getsize(path) == expect_bytes):
        print('cached  %s (%d B)' % (os.path.basename(path), os.path.getsize(path)))
        return
    print('fetch   %s' % url)
    req = urllib.request.Request(url, headers={'User-Agent': 'ShootStudio/1.3 (rtmpose-spike)'})
    with urllib.request.urlopen(req, timeout=600) as resp, open(path + '.part', 'wb') as fh:
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            fh.write(chunk)
    os.replace(path + '.part', path)
    print('saved   %s (%d B)' % (os.path.basename(path), os.path.getsize(path)))


def cmd_fetch(args):
    os.makedirs(args.stage, exist_ok=True)
    for name, (url, repo, license_id, size) in MODELS.items():
        if args.only and name not in args.only.split(','):
            continue
        fetch_one(url, os.path.join(args.stage, name), size)
    print('stage: %s' % args.stage)


def load_models(args, det='yolox_m.onnx', pose='rtmw3d-x.onnx', det_size=None):
    from rtmlib.tools.object_detection.yolox import YOLOX
    from rtmlib.tools.pose_estimation.rtmpose3d import RTMPose3d
    det_path = os.path.join(args.stage, det)
    pose_path = os.path.join(args.stage, pose)
    if det_size is None:
        import onnx
        dims = onnx.load(det_path, load_external_data=False).graph.input[0].type.tensor_type.shape.dim
        det_size = (int(dims[2].dim_value), int(dims[3].dim_value))
    det_model = YOLOX(det_path, model_input_size=det_size, det_mode='human', score_thr=0.5)
    pose_model = RTMPose3d(pose_path, model_input_size=(288, 384), backend='onnxruntime', device='cpu')
    return det_model, pose_model


def biggest_box(det, img):
    boxes = det(img)
    if boxes is None or len(boxes) == 0:
        return None
    return boxes[int(np.argmax((boxes[:, 2] - boxes[:, 0]) * (boxes[:, 3] - boxes[:, 1])))]


def scale_from_bones(kp):
    est = []
    for i, j, prior in BONES:
        dxy = float(np.hypot(kp[i][0] - kp[j][0], kp[i][1] - kp[j][1]))
        dz = float(abs(kp[i][2] - kp[j][2]))
        if dxy < 4.0:
            continue
        v = prior * prior - dz * dz
        if v <= 0.01:
            continue
        est.append(np.sqrt(v) / dxy)
    return (float(statistics.median(est)) if est else 0.005), len(est)


def to_world33(kp, sc, s):
    world = np.zeros((33, 3), dtype=float)
    conf = [0.0] * 33
    for bp, rtmw in MAP33.items():
        world[bp] = np.array([kp[rtmw][0] * s, kp[rtmw][1] * s, kp[rtmw][2]])
        conf[bp] = float(sc[rtmw])
    return world - (world[23] + world[24]) / 2.0, conf


def joint_deg_diffs(j32, j8):
    diffs = []
    for name in JOINTS:
        diffs.extend([abs(float(j32[name][a]) - float(j8[name][a])) for a in range(3)])
    return diffs


def cmd_specs(args):
    import onnx
    report = {'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'models': []}
    for name, (url, repo, license_id, size) in MODELS.items():
        path = os.path.join(args.stage, name)
        entry = {'file': name, 'repo': repo, 'license': license_id,
                 'source_url': url, 'bytes': size, 'present': os.path.exists(path)}
        if entry['present']:
            model = onnx.load(path, load_external_data=False)
            entry['ir_version'] = int(model.ir_version)
            entry['inputs'] = [{'name': i.name, 'dtype': str(i.type.tensor_type.elem_type),
                                'shape': [d.dim_value for d in i.type.tensor_type.shape.dim]}
                               for i in model.graph.input]
            entry['outputs'] = [{'name': o.name,
                                 'shape': [d.dim_value for d in o.type.tensor_type.shape.dim]}
                                for o in model.graph.output]
            entry['actual_bytes'] = os.path.getsize(path)
        report['models'].append(entry)
        print('%-18s %-16s %-10s %s' % (name, repo, license_id, 'present' if entry['present'] else 'missing'))
    write_json(args, 'rtmpose-spike-specs.json', report)


def cmd_infer(args):
    det, pose = load_models(args)
    ids = (args.ids or 'p001').split(',')
    report = {'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'rows': []}
    for pid in ids:
        img = cv2.imread(os.path.join(PHOTOS, pid + '.jpg'))
        box = biggest_box(det, img)
        t0 = time.perf_counter()
        kp, sc = pose(img, [box.tolist()])[0][0], pose(img, [box.tolist()])[1][0]
        ms = (time.perf_counter() - t0) * 1000
        s, n = scale_from_bones(kp)
        row = {'id': pid, 'box': [round(float(v), 1) for v in box], 'pose_ms': round(ms, 1),
               'scale_m_per_px': round(s, 5), 'scale_bones': n,
               'nose_z_m': round(float(kp[0][2]), 3), 'hip_z_m': round(float((kp[11][2] + kp[12][2]) / 2), 3),
               'ankle_z_m': round(float((kp[15][2] + kp[16][2]) / 2), 3)}
        report['rows'].append(row)
        print('[%s] box=%s pose=%.0fms scale=%.5f (n=%d) z nose/hip/ankle %.2f/%.2f/%.2f m' % (
            pid, row['box'], row['pose_ms'], row['scale_m_per_px'], n,
            row['nose_z_m'], row['hip_z_m'], row['ankle_z_m']))
    write_json(args, 'rtmpose-spike-infer.json', report)


def cmd_compare(args):
    det, pose = load_models(args)
    with open(POSES3, 'r', encoding='utf-8') as fh:
        poses = {p['id']: p for p in json.load(fh)['poses']}
    ids = (args.ids or ','.join(COMPARE_IMAGES)).split(',')
    report = {'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
              'note': 'RTMW3D-x (ONNX) vs shipped poses3.json (MediaPipe world landmarks); '
                      'not the D141 gate metric, which is porting fidelity (on-device vs Python).',
              'rows': []}
    all_diffs = []
    for pid in ids:
        img = cv2.imread(os.path.join(PHOTOS, pid + '.jpg'))
        box = biggest_box(det, img).tolist()
        kp, sc = pose(img, [box])[0][0], pose(img, [box])[1][0]
        s, _ = scale_from_bones(kp)
        world, conf = to_world33(kp, sc, s)
        cat = poses[pid]['category']
        j_new = s2j.derive(world, conf, cat)[0]
        j_ref = poses[pid]['joints']
        diffs = []
        for name in JOINTS:
            diffs.extend([abs(float(j_new[name][a]) - float(j_ref[name][a])) for a in range(3)])
        all_diffs.extend(diffs)
        row = {'id': pid, 'category': cat,
               'mean_deg': round(float(np.mean(diffs)), 2),
               'within5_pct': round(100.0 * float(np.mean([d <= 5 for d in diffs])), 1),
               'within10_pct': round(100.0 * float(np.mean([d <= 10 for d in diffs])), 1),
               'max_deg': round(float(np.max(diffs)), 2)}
        report['rows'].append(row)
        print('[%s] %-6s mean %6.2f°  ≤5° %5.1f%%  ≤10° %5.1f%%  max %6.2f°' % (
            pid, cat, row['mean_deg'], row['within5_pct'], row['within10_pct'], row['max_deg']))
    report['summary'] = {
        'mean_deg': round(float(np.mean(all_diffs)), 2),
        'within5_pct': round(100.0 * float(np.mean([d <= 5 for d in all_diffs])), 1),
        'within10_pct': round(100.0 * float(np.mean([d <= 10 for d in all_diffs])), 1),
        'angles': len(all_diffs),
    }
    print('summary: mean %.2f°  ≤5° %.1f%%  ≤10° %.1f%% (%d angles)' % (
        report['summary']['mean_deg'], report['summary']['within5_pct'],
        report['summary']['within10_pct'], report['summary']['angles']))
    write_json(args, 'rtmpose-spike-angle.json', report)


def cmd_reference(args):
    """D141 porting-fidelity reference: shipped models (yolox_tiny + rtmw3d fp16)."""
    det, pose = load_models(args, det='yolox_tiny.onnx', pose='rtmw3d-x-fp16.onnx')
    with open(POSES3, 'r', encoding='utf-8') as fh:
        poses = {p['id']: p for p in json.load(fh)['poses']}
    ids = (args.ids or ','.join(CONSISTENCY_IMAGES)).split(',')
    report = {'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
              'note': 'D141 porting fidelity: Python (rtmlib + MAP33 + derive + clamp_joint, '
                      'same as the poses3 build pipeline) on the shipped '
                      'models (yolox_tiny + rtmw3d-x fp16); the on-device Dart engine must match '
                      'within tolerance. Regenerate: python tool/rtmpose_spike.py reference',
              'det': 'yolox_tiny.onnx', 'pose': 'rtmw3d-x-fp16.onnx',
              'pipeline': {'padding': 1.25, 'outW': 288, 'outH': 384, 'zRange': 2.1744869},
              'rows': []}
    for pid in ids:
        img = cv2.imread(os.path.join(PHOTOS, pid + '.jpg'))
        if img is None:
            print('[%s] missing photo' % pid)
            continue
        h, w = img.shape[:2]
        box = biggest_box(det, img)
        if box is None:
            print('[%s] no detection' % pid)
            continue
        box = [round(float(v), 3) for v in box.tolist()]
        kp = pose(img, [box])[0][0]
        sc = pose(img, [box])[1][0]
        s, bones = scale_from_bones(kp)
        world, conf = to_world33(kp, sc, s)
        cat = poses[pid]['category']
        joints, root_pitch, root_y, _dbg = s2j.derive(world, conf, cat)
        # 与生产管线（build()）一致：12 关节限位夹取（Dart deriveJoints 同口径）。
        clamps = []
        joints = {name: s2j.clamp_joint(name, joints[name], clamps, pid)
                  for name in joints}
        bw = (box[2] - box[0]) * 1.25
        bh = (box[3] - box[1]) * 1.25
        aspect = 288.0 / 384.0
        scale_w = bw if bw > bh * aspect else bh * aspect
        row = {
            'id': pid,
            'category': cat,
            'imageSize': [int(w), int(h)],
            'box': box,
            'spec': {'centerX': round((box[0] + box[2]) / 2, 3),
                     'centerY': round((box[1] + box[3]) / 2, 3),
                     'scaleW': round(scale_w, 3)},
            'scale': round(float(s), 6),
            'bonesUsed': int(bones),
            'keypoints': [[round(float(kp[i][0]), 4), round(float(kp[i][1]), 4),
                           round(float(kp[i][2]), 4), round(float(sc[i]), 4)]
                          for i in range(133)],
            'world33': [[round(float(v), 5) for v in pt] for pt in world.tolist()],
            'joints': {name: [round(float(v), 3) for v in joints[name]] for name in JOINTS},
            'rootPitch': round(float(root_pitch), 3),
            'rootY': round(float(root_y), 4),
        }
        report['rows'].append(row)
        print('[%s] %-6s box %s scale %.5f (bones %d) rootY %.4f rootPitch %.2f' % (
            pid, cat, box, s, bones, root_y, root_pitch))
    write_json(args, 'pose3d-consistency-reference.json', report)


def cmd_detcompare(args):
    from rtmlib.tools.object_detection.yolox import YOLOX
    import onnx

    def build(name):
        path = os.path.join(args.stage, name)
        dims = onnx.load(path, load_external_data=False).graph.input[0].type.tensor_type.shape.dim
        return YOLOX(path, model_input_size=(int(dims[2].dim_value), int(dims[3].dim_value)),
                     det_mode='human', score_thr=0.5)

    def iou(a, b):
        x0, y0 = max(a[0], b[0]), max(a[1], b[1])
        x1, y1 = min(a[2], b[2]), min(a[3], b[3])
        inter = max(0.0, x1 - x0) * max(0.0, y1 - y0)
        ua = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
        return inter / ua if ua > 0 else 0.0

    ref_det = build('yolox_m.onnx')
    report = {'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
              'reference': 'yolox_m.onnx (640x640)', 'rows': []}
    for name in ('yolox_s.onnx', 'yolox_tiny.onnx', 'yolox_nano.onnx'):
        det = build(name)
        ious, times = [], []
        for pid in DETECT_IMAGES:
            img = cv2.imread(os.path.join(PHOTOS, pid + '.jpg'))
            ref = biggest_box(ref_det, img)
            t0 = time.perf_counter()
            box = biggest_box(det, img)
            times.append((time.perf_counter() - t0) * 1000)
            ious.append(iou(ref, box))
        row = {'file': name, 'iou_vs_ref_mean': round(float(np.mean(ious)), 3),
               'iou_vs_ref_min': round(float(np.min(ious)), 3),
               'median_ms': round(statistics.median(times), 1),
               'bytes': os.path.getsize(os.path.join(args.stage, name))}
        report['rows'].append(row)
        print('%-16s IoU mean %.3f (min %.3f)  %.0f ms  %.1f MB' % (
            name, row['iou_vs_ref_mean'], row['iou_vs_ref_min'], row['median_ms'], row['bytes'] / 1e6))
    write_json(args, 'rtmpose-spike-detectors.json', report)


def cmd_quantize(args):
    from onnxruntime.quantization import (CalibrationDataReader, QuantFormat,
                                          QuantType, quantize_dynamic, quantize_static)
    from onnxruntime.transformers.float16 import convert_float_to_float16
    import onnx

    det, pose = load_models(args)
    report = {'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'variants': []}
    src_pose = os.path.join(args.stage, 'rtmw3d-x.onnx')

    def variant(name, path, model_size_mb):
        return {'name': name, 'file': os.path.basename(path), 'size_mb': round(model_size_mb, 1)}

    # dynamic int8
    dyn = os.path.join(args.stage, 'rtmw3d-x-int8.onnx')
    quantize_dynamic(src_pose, dyn, weight_type=QuantType.QInt8)
    report['variants'].append(variant('dynamic-int8', dyn, os.path.getsize(dyn) / 1e6))

    # static int8 with calibration on real crops
    class Reader(CalibrationDataReader):
        def __init__(self, arrays):
            self.arrays = arrays
            self.it = iter(arrays)

        def get_next(self):
            try:
                return {'input': next(self.it)}
            except StopIteration:
                return None

        def rewind(self):
            self.it = iter(self.arrays)

    cal_ids = ['p%03d' % i for i in range(2, 121, 4)]
    arrays = []
    for pid in cal_ids:
        img = cv2.imread(os.path.join(PHOTOS, pid + '.jpg'))
        if img is None:
            continue
        resized, _, _ = pose.preprocess(img, biggest_box(det, img).tolist())
        arrays.append(np.ascontiguousarray(resized.transpose(2, 0, 1)[None].astype(np.float32)))
    sta = os.path.join(args.stage, 'rtmw3d-x-static-int8.onnx')
    quantize_static(src_pose, sta, Reader(arrays), quant_format=QuantFormat.QDQ,
                    per_channel=True, weight_type=QuantType.QInt8, activation_type=QuantType.QUInt8)
    report['variants'].append(variant('static-int8', sta, os.path.getsize(sta) / 1e6))

    # fp16
    f16 = os.path.join(args.stage, 'rtmw3d-x-fp16.onnx')
    model = convert_float_to_float16(onnx.load(src_pose), keep_io_types=True)
    onnx.save(model, f16)
    report['variants'].append(variant('fp16', f16, os.path.getsize(f16) / 1e6))

    # quality deltas vs fp32 (same pipeline as compare)
    from rtmlib.tools.pose_estimation.rtmpose3d import RTMPose3d
    with open(POSES3, 'r', encoding='utf-8') as fh:
        poses = {p['id']: p for p in json.load(fh)['poses']}
    for entry in report['variants']:
        path = os.path.join(args.stage, entry['file'])
        try:
            p8 = RTMPose3d(path, model_input_size=(288, 384), backend='onnxruntime', device='cpu')
        except Exception as exc:  # noqa: BLE001
            entry['error'] = repr(exc)
            print('%-14s LOAD FAILED %r' % (entry['name'], exc))
            continue
        diffs = []
        xy, zz, ms = [], [], []
        for pid in DETECT_IMAGES:
            img = cv2.imread(os.path.join(PHOTOS, pid + '.jpg'))
            box = biggest_box(det, img).tolist()
            kp32, sc32 = pose(img, [box])[0][0], pose(img, [box])[1][0]
            t0 = time.perf_counter()
            kp8, sc8 = p8(img, [box])[0][0], p8(img, [box])[1][0]
            ms.append((time.perf_counter() - t0) * 1000)
            xy.append(float(np.mean(np.linalg.norm(kp32[:, :2] - kp8[:, :2], axis=1))))
            zz.append(float(np.mean(np.abs(kp32[:, 2] - kp8[:, 2]))))
            s32, _ = scale_from_bones(kp32)
            s8, _ = scale_from_bones(kp8)
            cat = poses[pid]['category']
            j32 = s2j.derive(to_world33(kp32, sc32, s32)[0], to_world33(kp32, sc32, s32)[1], cat)[0]
            j8 = s2j.derive(to_world33(kp8, sc8, s8)[0], to_world33(kp8, sc8, s8)[1], cat)[0]
            diffs.extend(joint_deg_diffs(j32, j8))
        entry.update({
            'joint_deg_mean': round(float(np.mean(diffs)), 2),
            'joint_deg_max': round(float(np.max(diffs)), 2),
            'kpt_xy_px_mean': round(float(np.mean(xy)), 2),
            'kpt_z_m_mean': round(float(np.mean(zz)), 4),
            'pose_ms_median': round(statistics.median(ms), 1),
        })
        print('%-14s %6.1f MB | joint Δ mean %6.2f° max %6.2f° | kpt xy %.2f px, z %.3f m | %.0f ms' % (
            entry['name'], entry['size_mb'], entry['joint_deg_mean'], entry['joint_deg_max'],
            entry['kpt_xy_px_mean'], entry['kpt_z_m_mean'], entry['pose_ms_median']))
    report['base'] = {'file': 'rtmw3d-x.onnx', 'size_mb': round(os.path.getsize(src_pose) / 1e6, 1)}
    write_json(args, 'rtmpose-spike-quant.json', report)


def cmd_bench(args):
    import onnxruntime as ort
    eps = ['CPUExecutionProvider']
    if 'DmlExecutionProvider' in ort.get_available_providers():
        eps.append('DmlExecutionProvider')
    report = {'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
              'ort': ort.__version__, 'providers': ort.get_available_providers(), 'rows': []}
    x = np.random.rand(1, 3, 384, 288).astype(np.float32)
    names = [n for n in ('rtmw3d-x.onnx', 'rtmw3d-x-fp16.onnx', 'rtmw3d-x-static-int8.onnx',
                         'rtmw3d-x-int8.onnx') if os.path.exists(os.path.join(args.stage, n))]
    for name in names:
        for ep in eps:
            so = ort.SessionOptions()
            so.log_severity_level = 3
            try:
                sess = ort.InferenceSession(os.path.join(args.stage, name), sess_options=so, providers=[ep])
                sess.run(None, {sess.get_inputs()[0].name: x})
                ms = []
                for _ in range(5):
                    t0 = time.perf_counter()
                    sess.run(None, {sess.get_inputs()[0].name: x})
                    ms.append((time.perf_counter() - t0) * 1000)
                row = {'file': name, 'ep': ep, 'median_ms': round(statistics.median(ms), 1)}
                report['rows'].append(row)
                print('%-28s %-22s %7.1f ms' % (name, ep, row['median_ms']))
            except Exception as exc:  # noqa: BLE001
                report['rows'].append({'file': name, 'ep': ep, 'error': repr(exc)})
                print('%-28s %-22s FAILED %r' % (name, ep, exc))
    write_json(args, 'rtmpose-spike-bench.json', report)


def cmd_split(args):
    """Verify the GitHub 100MiB workaround: chunked fp16 model reassembles losslessly."""
    import hashlib
    import onnxruntime as ort

    limit = 100 * 1024 * 1024  # GitHub hard limit per file (100 MiB)
    src = os.path.join(args.stage, 'rtmw3d-x-fp16.onnx')
    if not os.path.exists(src):
        print('missing %s (run quantize first)' % src)
        return 1

    def sha256(path):
        h = hashlib.sha256()
        with open(path, 'rb') as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b''):
                h.update(chunk)
        return h.hexdigest()

    size = os.path.getsize(src)
    n_parts = int(np.ceil(size / (limit - 2 * 1024 * 1024)))
    part_size = int(np.ceil(size / n_parts))
    parts = []
    with open(src, 'rb') as fh:
        for i in range(n_parts):
            data = fh.read(part_size)
            path = '%s.part%d' % (src, i)
            with open(path, 'wb') as out:
                out.write(data)
            parts.append({'name': os.path.basename(path), 'bytes': len(data),
                          'sha256': hashlib.sha256(data).hexdigest()})
            print('  %s %d bytes' % (parts[-1]['name'], len(data)))

    joined = os.path.join(args.stage, 'rtmw3d-x-fp16.rejoined.onnx')
    with open(joined, 'wb') as out:
        for p in parts:
            with open(os.path.join(args.stage, p['name']), 'rb') as fh:
                out.write(fh.read())
    h_src, h_join = sha256(src), sha256(joined)

    x = np.random.RandomState(0).randn(1, 3, 384, 288).astype(np.float32)
    outs = {}
    for tag, path in (('orig', src), ('joined', joined)):
        sess = ort.InferenceSession(path, providers=['CPUExecutionProvider'])
        outs[tag] = sess.run(None, {'input': x})
    diffs = [float(np.max(np.abs(a - b))) for a, b in zip(outs['orig'], outs['joined'])]
    report = {'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
              'purpose': 'GitHub blocks files >100 MiB; fp16 model is chunked for bundling (R64)',
              'src_bytes': size, 'src_sha256': h_src, 'limit_bytes': limit,
              'parts': parts, 'rejoined_sha256': h_join, 'sha_match': h_src == h_join,
              'max_abs_diff': diffs, 'identical': all(d == 0.0 for d in diffs)}
    print('sha match %s | ORT outputs identical %s (max diff %s)' % (
        report['sha_match'], report['identical'], diffs))
    write_json(args, 'rtmpose-spike-split.json', report)


def write_json(args, name, payload):
    os.makedirs(args.out, exist_ok=True)
    path = os.path.join(args.out, name)
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write('\n')
    print('written %s' % path)


def main():
    parser = argparse.ArgumentParser(description='V7/S5 RTMPose/RTMW3D spike (R67)')
    parser.add_argument('command', choices=['fetch', 'specs', 'infer', 'compare', 'detcompare', 'quantize', 'bench', 'split', 'reference'])
    parser.add_argument('--stage', default=DEFAULT_STAGE)
    parser.add_argument('--out', default=DEFAULT_OUT)
    parser.add_argument('--ids', default='')
    parser.add_argument('--only', default='')
    args = parser.parse_args()
    return {'fetch': cmd_fetch, 'specs': cmd_specs, 'infer': cmd_infer, 'compare': cmd_compare,
            'detcompare': cmd_detcompare, 'quantize': cmd_quantize, 'bench': cmd_bench,
            'split': cmd_split, 'reference': cmd_reference}[args.command](args) or 0


if __name__ == '__main__':
    sys.exit(main())
