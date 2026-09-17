# -*- coding: utf-8 -*-
"""D1 清理：把 assets/content/gear/photo2 中非内置（builtin != true）的图片
移动到 tool/gear_photo_pool/，保持「内置 Top100 压缩版」的包体预算（R22/D73）。"""
import json
import os
import shutil

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHOTO_DIR = os.path.join(APP, 'assets', 'content', 'gear', 'photo2')
POOL_DIR = os.path.join(APP, 'tool', 'gear_photo_pool')
CATALOG = os.path.join(APP, 'assets', 'content', 'gear', 'gear_photos2.json')

with open(CATALOG, 'r', encoding='utf-8') as fh:
    data = json.load(fh)
by_id = data.get('byId', {})
builtin_files = {
    v.get('file') for v in by_id.values() if v.get('builtin') and v.get('file')
}
os.makedirs(POOL_DIR, exist_ok=True)
moved = 0
kept = 0
for name in sorted(os.listdir(PHOTO_DIR)):
    src = os.path.join(PHOTO_DIR, name)
    if not os.path.isfile(src):
        continue
    if name in builtin_files:
        kept += 1
        continue
    dst = os.path.join(POOL_DIR, name)
    shutil.move(src, dst)
    moved += 1
print('[cleanup] kept %d builtin, moved %d non-builtin -> %s' % (kept, moved, POOL_DIR))
print('[cleanup] builtin files referenced: %d (on disk: %d)' % (len(builtin_files), kept))
