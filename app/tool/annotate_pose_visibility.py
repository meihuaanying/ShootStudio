# -*- coding: utf-8 -*-
"""标注 poses3.json 的 partialBody（半身/特写照片）：照片中人体关键点的纵向
跨度异常（过小=特写裁剪；过大=关键点外推失真）时，3D 关节复现仅供构图参考。

仅补充字段，不改动 joints/rootY/rootPitch（保留 QA 接地校准）。

用法（工作目录 app/）：
  python tool/annotate_pose_visibility.py
"""
import json
import os

POSE_DIR = os.path.join('assets', 'content', 'poses3')
PHOTOS_DIR = os.path.join(POSE_DIR, 'photos')
OUT = os.path.join(POSE_DIR, 'poses3.json')

# 归一化关键点纵向跨度的合理区间（全身入画 ≈ 0.45..1.2）。
SPAN_MIN = 0.45
SPAN_MAX = 1.2


def main():
    with open(OUT, 'r', encoding='utf-8') as fh:
        payload = json.load(fh)
    partial = 0
    for pose in payload['poses']:
        skel_path = os.path.join(PHOTOS_DIR, '%s.skeleton.json' % pose['id'])
        try:
            with open(skel_path, 'r', encoding='utf-8') as fh:
                skel = json.load(fh)
        except Exception:  # noqa: BLE001
            pose['partialBody'] = False
            pose.pop('partialReason', None)
            continue
        lm = skel.get('landmarks2d', [])
        ys = [float(row[1]) for row in lm if len(row) > 1]
        span = (max(ys) - min(ys)) if ys else 0.0
        pose['bodySpan'] = round(span, 3)
        if span < SPAN_MIN:
            pose['partialBody'] = True
            pose['partialReason'] = '照片为半身/特写（关键点跨度 %.2f），下肢未入画' % span
            partial += 1
        elif span > SPAN_MAX:
            pose['partialBody'] = True
            pose['partialReason'] = '关键点跨度异常（%.2f），身体外推失真' % span
            partial += 1
        else:
            pose['partialBody'] = False
            pose.pop('partialReason', None)
    payload['visibility'] = {
        'spanRange': [SPAN_MIN, SPAN_MAX],
        'partialCount': partial,
        'note': 'partialBody 表示照片为半身/特写或关键点外推失真，3D 关节复现仅供构图参考。',
    }
    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
    from collections import Counter
    counts = Counter()
    for pose in payload['poses']:
        if pose.get('partialBody'):
            counts[pose['category']] += 1
    print('[partial] %d/%d：%s' %
          (partial, len(payload['poses']), json.dumps(counts, ensure_ascii=False)))


if __name__ == '__main__':
    main()
