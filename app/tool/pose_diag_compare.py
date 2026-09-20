# -*- coding: utf-8 -*-
"""诊断：在 Dart 导出的 letterbox 裁剪图上跑 MediaPipe PoseLandmarker，
与 Dart 端 world landmarks / Python 原图结果对比。"""
import json
import os
import sys

import mediapipe as mp
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision
import numpy as np

TEMP = os.environ['TEMP']
TASK = os.path.join(TEMP, 'pose_landmarker_full.task')
ID = sys.argv[1] if len(sys.argv) > 1 else 'p008'
CROP = os.path.join(TEMP, f'{ID}_pkgcrop.png')
OURS = os.path.join(TEMP, f'{ID}_world_ours.json')
SKEL = os.path.join('assets', 'content', 'poses3', 'photos', f'{ID}.skeleton.json')

opts = mp_python.BaseOptions(model_asset_path=TASK)
options = vision.PoseLandmarkerOptions(
    base_options=opts,
    running_mode=vision.RunningMode.IMAGE,
    num_poses=1,
    output_segmentation_masks=False,
)
landmarker = vision.PoseLandmarker.create_from_options(options)

img = mp.Image.create_from_file(CROP)
result = landmarker.detect(img)
if not result.pose_world_landmarks:
    print('crop 上未检测到人物')
    sys.exit(1)
mp_world = np.array([[p.x, p.y, p.z] for p in result.pose_world_landmarks[0]])
ours = np.array(json.load(open(OURS, encoding='utf-8'))['world'])
py_orig = np.array(json.load(open(SKEL, encoding='utf-8'))['world3d'])

def stats(a, b, name):
    d = np.linalg.norm(a - b, axis=1)
    print(f'{name}: mean={d.mean():.4f} max={d.max():.4f} m')
    return d

print('点数', len(mp_world), len(ours), len(py_orig))
stats(mp_world, ours, 'MediaPipe(crop) vs Dart(crop)')
stats(mp_world, py_orig, 'MediaPipe(crop) vs Python(原图)')
stats(ours, py_orig, 'Dart(crop) vs Python(原图)')

# 角度无关性：逐点方向余弦
def dirs(a):
    return a / np.maximum(np.linalg.norm(a, axis=1, keepdims=True), 1e-9)
cos_ours = np.sum(dirs(mp_world) * dirs(ours), axis=1)
cos_py = np.sum(dirs(mp_world) * dirs(py_orig), axis=1)
print('方向余弦均值 MPvsDart =', round(float(cos_ours.mean()), 4),
      'MPvsPy =', round(float(cos_py.mean()), 4))
for i, name in [(0, 'nose'), (11, 'l_sho'), (15, 'l_wri'), (23, 'l_hip'), (27, 'l_ank')]:
    print(name, 'MP', np.round(mp_world[i], 3), 'Dart', np.round(ours[i], 3),
          'Py', np.round(py_orig[i], 3))
