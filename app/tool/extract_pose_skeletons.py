# -*- coding: utf-8 -*-
"""姿势骨架提取（V4 / D66、R20）：MediaPipe BlazePose（Tasks PoseLandmarker）。

对 assets/content/poses3/photos/<id>.jpg 逐张检测：
  - 33 个归一化 2D landmarks（x, y, z, visibility）
  - 33 个 world landmarks（米，hip 中心，camera 坐标系）
  - 透明底骨架叠加图 docs/pose-qa3/overlay-<id>.png（与原图同尺寸；D66/R19：
    叠加图只是 QA 证据，不放进 assets——应用端用 CustomPainter 直接读 skeleton.json 绘制）
  - <id>.skeleton.json：{landmarks2d, world3d, confidence, imageSize, personDetected, model}
无人可检测的照片写入 poses3/rejects.json，供 gen_pose_photos.dart --fix 换图。

用法（工作目录 app/）：
  python tool/extract_pose_skeletons.py                # 增量提取（跳过已完成）
  python tool/extract_pose_skeletons.py --force        # 全部重跑
  python tool/extract_pose_skeletons.py --ids p001,p002
  python tool/extract_pose_skeletons.py stitch --id p001 --photo ... --overlay ... --render ... --out ...
  python tool/extract_pose_skeletons.py stitch-batch --poses assets/content/poses3/poses3.json \
      --renders <dir> --out docs/pose-qa3
"""
import argparse
import json
import os
import shutil
import sys
import tempfile
import time
import urllib.request

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:  # Wikimedia/模型站点 DNS 受影响时走 DoH；失败则回退直连。
    import doh

    doh.install()
except Exception as _doh_exc:  # noqa: BLE001
    print('[doh] 未启用：%s' % _doh_exc)

POSE_DIR = os.path.join('assets', 'content', 'poses3')
PHOTOS_DIR = os.path.join(POSE_DIR, 'photos')
MANIFEST = os.path.join(POSE_DIR, 'photos_manifest.json')
REJECTS = os.path.join(POSE_DIR, 'rejects.json')

APP_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO_ROOT = os.path.dirname(APP_ROOT)
QA_DIR = os.path.join(REPO_ROOT, 'docs', 'pose-qa3')


def resolve_path(rel):
    """把 app 相对（assets/...）或仓库相对（docs/...）路径解析为存在的实际路径。"""
    if not rel:
        return ''
    if os.path.isabs(rel):
        return rel
    for base in (os.getcwd(), APP_ROOT, REPO_ROOT):
        candidate = os.path.join(base, rel)
        if os.path.exists(candidate):
            return candidate
    return rel

MODEL_URLS = [
    'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/latest/pose_landmarker_full.task',
    'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task',
]

# MediaPipe 官方姿势连接表（33 关键点）。
POSE_CONNECTIONS = [
    (0, 1), (1, 2), (2, 3), (3, 7), (0, 4), (4, 5), (5, 6), (6, 8),
    (9, 10), (11, 12), (11, 13), (13, 15), (15, 17), (15, 19), (15, 21),
    (17, 19), (12, 14), (14, 16), (16, 18), (16, 20), (16, 22), (18, 20),
    (11, 23), (12, 24), (23, 24),
    (23, 25), (24, 26), (25, 27), (26, 28), (27, 29), (28, 30),
    (29, 31), (30, 32), (27, 31), (28, 32),
]

EDGES_COLOR = {
    'torso': (255, 196, 0),
    'arm': (0, 200, 255),
    'leg': (110, 230, 120),
    'face': (255, 120, 190),
}


def model_cache_dir():
    override = os.environ.get('SHOOTSTUDIO_POSE_MODEL_DIR')
    if override:
        return override
    base = os.environ.get('LOCALAPPDATA') or os.path.expanduser('~/.cache')
    return os.path.join(base, 'ShootStudio', 'pose_models')


def ensure_model(cache):
    os.makedirs(cache, exist_ok=True)
    last = None
    for url in MODEL_URLS:
        name = url.rsplit('/', 1)[-1]
        dst = os.path.join(cache, name)
        if os.path.exists(dst) and os.path.getsize(dst) > 1_000_000:
            return dst
        for attempt in range(1, 4):
            try:
                print('[model] 下载 %s（第 %d 次）' % (name, attempt))
                fd, tmp = tempfile.mkstemp(suffix='.task')
                os.close(fd)
                urllib.request.urlretrieve(url, tmp)
                if os.path.getsize(tmp) < 1_000_000:
                    raise RuntimeError('下载不完整')
                shutil.copyfile(tmp, dst)
                os.remove(tmp)
                print('[model] 完成 %s（%.1f MB）' % (name, os.path.getsize(dst) / 1e6))
                return dst
            except Exception as exc:  # noqa: BLE001
                last = exc
                print('[model] 失败：%s' % exc)
                time.sleep(2 * attempt)
    raise RuntimeError('MediaPipe 模型下载失败：%s' % last)


def edge_color(a, b):
    if a <= 10 and b <= 10:
        return EDGES_COLOR['face']
    if a in (11, 12) and b in (11, 12, 23, 24):
        return EDGES_COLOR['torso']
    if a == 23 and b == 24:
        return EDGES_COLOR['torso']
    if b >= 23 or a >= 23:
        return EDGES_COLOR['leg']
    return EDGES_COLOR['arm']


def draw_overlay(image_path, landmarks, out_path):
    base = Image.open(image_path).convert('RGBA')
    w, h = base.size
    overlay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    pts = [(lm[0] * w, lm[1] * h) for lm in landmarks]
    width = max(2, int(round(w * 0.006)))  # 线宽 = 图宽 0.6%
    radius = max(2, width)
    for a, b in POSE_CONNECTIONS:
        vis = min(landmarks[a][3], landmarks[b][3])
        color = edge_color(a, b) + (int(255 * max(0.25, min(1.0, vis))),)
        draw.line([pts[a], pts[b]], fill=color, width=width)
    for i, (x, y) in enumerate(pts):
        vis = landmarks[i][3]
        color = (255, 255, 255, 235) if vis >= 0.5 else (255, 96, 96, 160)
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=color)
    overlay.save(out_path)
    return w, h


def read_json(path, fallback):
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return fallback


def load_landmarker(model_path):
    import mediapipe as mp
    from mediapipe.tasks.python import BaseOptions
    from mediapipe.tasks.python import vision

    options = vision.PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=model_path),
        running_mode=vision.RunningMode.IMAGE,
        num_poses=1,
        min_pose_detection_confidence=0.3,
        min_pose_presence_confidence=0.3,
        min_tracking_confidence=0.3,
    )
    return mp, vision.PoseLandmarker.create_from_options(options)


def extract(ids=None, force=False, limit=0, cache=None, overlay_dir=None):
    manifest = read_json(MANIFEST, {})
    photos = manifest.get('photos', [])
    if not photos:
        print('[skeleton] 缺少 photos_manifest.json，请先运行 gen_pose_photos.dart')
        return 2
    overlay_dir = overlay_dir or QA_DIR
    os.makedirs(overlay_dir, exist_ok=True)
    cache = cache or model_cache_dir()
    model_path = ensure_model(cache)
    mp, landmarker = load_landmarker(model_path)

    rejects = {}
    current = read_json(REJECTS, {}).get('rejected', [])
    for item in current:
        if isinstance(item, dict) and item.get('id'):
            rejects[item['id']] = item.get('reason', 'unknown')

    done = skipped = failed = 0
    todo = [p for p in photos if not ids or p.get('id') in ids]
    for entry in todo:
        if limit and done + skipped >= limit:
            break
        pid = entry.get('id')
        photo_rel = entry.get('photo', '')
        photo_path = photo_rel.split('assets/', 1)[-1]
        photo_path = os.path.join('assets', photo_path)
        if not os.path.exists(photo_path):
            print('[skeleton] %s 缺照片 %s' % (pid, photo_path))
            rejects[pid] = '照片缺失'
            continue
        skel_path = os.path.join(PHOTOS_DIR, '%s.skeleton.json' % pid)
        overlay_path = os.path.join(overlay_dir, 'overlay-%s.png' % pid)
        # 清理历史版本误放在 assets 内的叠加图（D66：叠加图只属于 QA 证据）。
        legacy_overlay = os.path.join(PHOTOS_DIR, '%s.overlay.png' % pid)
        if os.path.exists(legacy_overlay):
            os.remove(legacy_overlay)
        if not force and os.path.exists(skel_path) and os.path.exists(overlay_path):
            data = read_json(skel_path, {})
            if data.get('personDetected') and os.path.getmtime(skel_path) >= os.path.getmtime(photo_path):
                rejects.pop(pid, None)
                skipped += 1
                continue
        try:
            import mediapipe as _mp  # noqa: F401
            mp_image = mp.Image.create_from_file(photo_path)
            result = landmarker.detect(mp_image)
        except Exception as exc:  # noqa: BLE001
            print('[skeleton] %s 检测异常：%s' % (pid, exc))
            rejects[pid] = '检测异常：%s' % exc
            failed += 1
            continue
        if not result.pose_landmarks:
            print('[skeleton] %s 未检测到人体（标记待换图）' % pid)
            with open(skel_path, 'w', encoding='utf-8') as fh:
                json.dump({
                    'id': pid, 'photo': photo_rel, 'personDetected': False,
                    'confidence': 0.0, 'model': os.path.basename(model_path),
                    'landmarks2d': [], 'world3d': [], 'imageSize': [],
                }, fh, ensure_ascii=False, indent=2)
            if os.path.exists(overlay_path):
                os.remove(overlay_path)
            rejects[pid] = '未检测到人体'
            continue
        norm = result.pose_landmarks[0]
        world = result.pose_world_landmarks[0]
        landmarks2d = [[float(lm.x), float(lm.y), float(lm.z), float(getattr(lm, 'visibility', 0.0))] for lm in norm]
        world3d = [[float(lm.x), float(lm.y), float(lm.z)] for lm in world]
        vis = [lm[3] for lm in landmarks2d]
        confidence = round(sum(vis) / len(vis), 4) if vis else 0.0
        image_size = list(Image.open(photo_path).size)
        draw_overlay(photo_path, landmarks2d, overlay_path)
        payload = {
            'id': pid,
            'photo': photo_rel,
            'personDetected': True,
            'confidence': confidence,
            'model': os.path.basename(model_path),
            'landmarks2d': [[round(v, 6) for v in lm] for lm in landmarks2d],
            'world3d': [[round(v, 6) for v in lm] for lm in world3d],
            'imageSize': image_size,
        }
        with open(skel_path, 'w', encoding='utf-8') as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
        rejects.pop(pid, None)
        done += 1
        if done % 10 == 0:
            print('[skeleton] 进度 %d（跳过 %d）' % (done, skipped))

    payload = {
        'version': 1,
        'updatedAt': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'rejected': [{'id': k, 'reason': v} for k, v in sorted(rejects.items())],
    }
    with open(REJECTS, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
    landmarker.close()
    print('[skeleton] 提取 %d，跳过 %d，失败 %d，待换图 %d' % (done, skipped, failed, len(rejects)))
    return 0


FONT_CANDIDATES = [
    os.path.join(os.environ.get('WINDIR', r'C:\Windows'), 'Fonts', 'msyh.ttc'),
    os.path.join(os.environ.get('WINDIR', r'C:\Windows'), 'Fonts', 'simhei.ttf'),
    '/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc',
    '/System/Library/Fonts/PingFang.ttc',
]


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:  # noqa: BLE001
                continue
    return ImageFont.load_default()


def stitch(photo, overlay, render, out, label=''):
    """把 原图 | 照片+骨架叠加 | 3D 渲染 横向拼接为对比图。"""
    panels = []
    orig = Image.open(photo).convert('RGBA')
    ov = Image.open(overlay).convert('RGBA')
    if ov.size != orig.size:
        ov = ov.resize(orig.size)
    combo = Image.alpha_composite(orig, ov)
    panels.append(orig.convert('RGB'))
    panels.append(combo.convert('RGB'))
    if render:
        r = Image.open(render).convert('RGBA')
        bg = Image.new('RGBA', r.size, (238, 241, 245, 255))
        panels.append(Image.alpha_composite(bg, r).convert('RGB'))
    height = max(p.height for p in panels)
    scaled = []
    for p in panels:
        if p.height != height:
            p = p.resize((max(1, int(p.width * height / p.height)), height), Image.LANCZOS)
        scaled.append(p)
    gap = 12
    width = sum(p.width for p in scaled) + gap * (len(scaled) - 1)
    bar = 56 if label else 0
    canvas = Image.new('RGB', (width, height + bar), (30, 34, 40))
    x = 0
    for p in scaled:
        canvas.paste(p, (x, bar))
        x += p.width + gap
    if label:
        draw = ImageDraw.Draw(canvas)
        draw.text((14, 8), label, fill=(240, 244, 250), font=load_font(30))
        draw.text((14, 34), '原图 | 照片+骨架叠加 | 3D 引擎渲染（person/character 同款语义）',
                  fill=(150, 158, 170), font=load_font(17))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.save(out)
    return canvas.size


def stitch_batch(poses_file, renders_dir, out_dir, ids=None):
    """批量拼接：读 poses3.json，输出 compare-<id>.png 与 overlay-<id>.png。"""
    data = read_json(poses_file, {})
    poses = data.get('poses', [])
    if not poses:
        print('[stitch-batch] 缺少 %s' % poses_file)
        return 2
    os.makedirs(out_dir, exist_ok=True)
    ok = missing = 0
    for pose in poses:
        pid = pose.get('id')
        if ids and pid not in ids:
            continue
        photo = resolve_path(pose.get('photo', ''))
        overlay = resolve_path(pose.get('overlayRel') or pose.get('overlay') or '')
        if not (photo and os.path.exists(photo) and os.path.exists(overlay)):
            print('[stitch-batch] %s 缺照片/叠加图' % pid)
            missing += 1
            continue
        render = ''
        char = ''
        if renders_dir:
            for name in os.listdir(renders_dir):
                if name.startswith('%s__' % pid) and name.endswith('.png'):
                    render = os.path.join(renders_dir, name)
                    char = name[len(pid) + 2:-4]
                    break
            if not render:
                direct = os.path.join(renders_dir, '%s.png' % pid)
                if os.path.exists(direct):
                    render = direct
        label = '%s · %s · %s · conf %.2f%s%s' % (
            pid, pose.get('name', ''), pose.get('category', ''),
            float(pose.get('confidence', 0.0)),
            '（仅供构图参考）' if pose.get('referenceOnly') else '',
            ' · %s' % char if char else '')
        out = os.path.join(out_dir, 'compare-%s.png' % pid)
        stitch(photo, overlay, render, out, label)
        overlay_out = os.path.join(out_dir, 'overlay-%s.png' % pid)
        if os.path.abspath(overlay) != os.path.abspath(overlay_out):
            shutil.copyfile(overlay, overlay_out)
        ok += 1
    print('[stitch-batch] 拼接 %d 张（缺 %d）-> %s' % (ok, missing, out_dir))
    return 0 if missing == 0 else 1


def main():
    parser = argparse.ArgumentParser(description='MediaPipe BlazePose 骨架提取（poses3）')
    parser.add_argument('command', nargs='?', default='extract',
                        choices=['extract', 'stitch', 'stitch-batch'])
    parser.add_argument('--ids', default='')
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--limit', type=int, default=0)
    parser.add_argument('--cache', default='')
    parser.add_argument('--overlay-dir', default='')
    parser.add_argument('--photo')
    parser.add_argument('--overlay')
    parser.add_argument('--render')
    parser.add_argument('--out')
    parser.add_argument('--label', default='')
    parser.add_argument('--poses', default=os.path.join(POSE_DIR, 'poses3.json'))
    parser.add_argument('--renders', default='')
    args = parser.parse_args()
    if args.command == 'stitch':
        if not (args.photo and args.overlay and args.out):
            parser.error('stitch 需要 --photo --overlay --out')
        size = stitch(args.photo, args.overlay, args.render, args.out, args.label)
        print('[stitch] %s -> %s' % (str(size), args.out))
        return 0
    if args.command == 'stitch-batch':
        if not args.out:
            parser.error('stitch-batch 需要 --out')
        ids = set(x.strip() for x in args.ids.split(',') if x.strip()) or None
        return stitch_batch(args.poses, args.renders, args.out, ids)
    ids = set(x.strip() for x in args.ids.split(',') if x.strip()) or None
    return extract(ids=ids, force=args.force, limit=args.limit, cache=args.cache or None,
                   overlay_dir=args.overlay_dir or None)


if __name__ == '__main__':
    sys.exit(main())
