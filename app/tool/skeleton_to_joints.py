# -*- coding: utf-8 -*-
"""骨架 -> 12 关节角（V4 / R20）：仅由 world3d（33 米制 landmarks，hip 中心）推导。

坐标系约定（与 app/assets/engine/js/person.js 一致，人物面向 +Z）：
  - 引擎关节角 [rx, ry, rz] 为 Three.js Euler 'XYZ'，旋转矩阵 R = Rx(rx)·Ry(ry)·Rz(rz)；
  - 假人静止朝向：躯干/颈向上 (0,1,0)，上臂/前臂/大腿/小腿向下 (0,-1,0)；
  - 肩/髋 + 肘/膝：双段肢体解（solve_limb）——父关节把静止段转到骨骼方向，扭转取
    「子关节铰链轴对齐局部 X 轴」的解，使肘/膝成为单轴铰链（肘屈曲为负 rx、膝为正 rx）；
  - 腕：肘坐标系内最小扭转解（手背/手指方向）；
  - 颈：由耳中点-肩中点（up）与鼻-耳中点（front）构造头部坐标系，
        用 Euler XYZ 反解 [rx, ry, rz]；
  - spine：ry = 肩线与髋线绕躯干轴的扭转角，rx/rz = 0（关节位置无法观测骨盆独立姿态）；
  - rootPitch：躯干轴与世界竖直在人体矢状面内的夹角（仰卧 <0、俯卧 >0、站立 ~0）；
    躺姿为「近水平」姿态，而引擎 root 只有绕 X 的 pitch（无 roll/yaw），侧卧的滚转不可
    表达，故按 person.js/旧姿势库约定收敛为 ±88°：可见「仰/俯」由鼻-耳方向（face_up）
    判定，侧卧取仰卧符号；非躺姿的 pitch 夹在 [-90, 90] 防倒立；
  - rootY：身体最低点相对髋中心的高度 - 引擎静止髋高 0.96 m（person.js hipY），
    取值范围 [-1.15, 0.6]（躺姿需要约 -0.9，旧姿势库同款量级）。

关节限位（越界夹取并记录）：elbow rx∈[-150,5]、knee rx∈[0,140]、hip rx∈[-120,40]、
shoulder rz∈[-90,90]、其余 ±180。
难度（与旧姿势库 gen_poses_v2 一致）：max(|12 关节角|, |rootPitch|) <28 新手友好 / <70 进阶 / 其余高难度。

输出：assets/content/poses3/poses3.json（version/note/poses/clamps）。

用法（工作目录 app/）：
  python tool/skeleton_to_joints.py build [--force]
  python tool/skeleton_to_joints.py debug --id p001
"""
import argparse
import json
import math
import os
import sys

import numpy as np

POSE_DIR = os.path.join('assets', 'content', 'poses3')
PHOTOS_DIR = os.path.join(POSE_DIR, 'photos')
MANIFEST = os.path.join(POSE_DIR, 'photos_manifest.json')
OUT = os.path.join(POSE_DIR, 'poses3.json')

# 与 person.js defaultJoints 一致的静止值（用于难度活动量与记录）。
REST = {
    'spine': [0, 0, 0], 'neck': [0, 0, 0],
    'shoulder_l': [0, 0, 8], 'elbow_l': [-12, 0, 0], 'wrist_l': [0, 0, 0],
    'shoulder_r': [0, 0, -8], 'elbow_r': [-12, 0, 0], 'wrist_r': [0, 0, 0],
    'hip_l': [-2, 0, 2], 'knee_l': [4, 0, 0], 'hip_r': [-2, 0, -2], 'knee_r': [4, 0, 0],
}

LIMITS = {
    'elbow': (0, -150.0, 5.0),
    'knee': (0, 0.0, 140.0),
    'hip': (0, -120.0, 40.0),
    'shoulder': (2, -90.0, 90.0),
}
GENERIC_LIMIT = 180.0

ENGINE_HIP_HEIGHT = 0.96  # person.js hipY = 0.96（默认身高 1.7 m）
ROOT_Y_MIN, ROOT_Y_MAX = -1.15, 0.6  # 躺姿约 -0.9（旧姿势库 rootY≈-1.0）

WORLD_UP = np.array([0.0, -1.0, 0.0])  # world landmark y 向下

L = dict(nose=0, l_ear=7, r_ear=8, l_sho=11, r_sho=12, l_elb=13, r_elb=14,
         l_wri=15, r_wri=16, l_pinky=17, r_pinky=18, l_index=19, r_index=20,
         l_hip=23, r_hip=24, l_kne=25, r_kne=26, l_ank=27, r_ank=28,
         l_heel=29, r_heel=30, l_foot=31, r_foot=32)


def read_json(path, fallback):
    try:
        with open(path, 'r', encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return fallback


def unit(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else np.zeros(3)


def euler_xyz(rx, ry, rz):
    """Three.js Euler 'XYZ'：R = Rx·Ry·Rz（角度制）。"""
    ax, ay, az = math.radians(rx), math.radians(ry), math.radians(rz)
    cx, sx = math.cos(ax), math.sin(ax)
    cy, sy = math.cos(ay), math.sin(ay)
    cz, sz = math.cos(az), math.sin(az)
    return np.array([
        [cy * cz, -cy * sz, sy],
        [sx * sy * cz + cx * sz, cx * cz - sx * sy * sz, -sx * cy],
        [sx * sz - cx * sy * cz, sx * cz + cx * sy * sz, cx * cy],
    ])


def euler_from_matrix(R):
    """由旋转矩阵反解 Euler XYZ（度）；gimbal lock 时 rz=0。"""
    sy = float(np.clip(R[0, 2], -1.0, 1.0))
    ry = math.degrees(math.asin(sy))
    if abs(sy) < 0.999999:
        rx = math.degrees(math.atan2(-R[1, 2], R[2, 2]))
        rz = math.degrees(math.atan2(-R[0, 1], R[0, 0]))
    elif sy > 0:
        rx = math.degrees(math.atan2(R[1, 0], R[1, 1]))
        rz = 0.0
    else:
        rx = -math.degrees(math.atan2(R[1, 0], R[1, 1]))
        rz = 0.0
    return [rx, ry, rz]


def solve_down(b):
    """最小扭转解：求 [rx,0,rz] 使 R·(0,-1,0)=b（b 为单位向量）。"""
    x = float(np.clip(b[0], -1.0, 1.0))
    rz = math.degrees(math.asin(x))
    cz = math.sqrt(max(0.0, 1.0 - x * x))
    if cz < 1e-6:
        rx = 0.0
    else:
        rx = math.degrees(math.atan2(-b[2], -b[1]))
    return [rx, 0.0, rz]


def rot_y(deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0.0, s], [0.0, 1.0, 0.0], [-s, 0.0, c]])


# 各关节三轴限位（未列出的轴为 ±180）。
JOINT_LIMITS = {
    'shoulder': {0: (-180.0, 180.0), 1: (-180.0, 180.0), 2: (-90.0, 90.0)},
    'elbow': {0: (-150.0, 5.0), 1: (-180.0, 180.0), 2: (-180.0, 180.0)},
    'hip': {0: (-120.0, 40.0), 1: (-180.0, 180.0), 2: (-180.0, 180.0)},
    'knee': {0: (0.0, 140.0), 1: (-180.0, 180.0), 2: (-180.0, 180.0)},
}


def limit_penalty(angles, limits):
    """超出限位的总度数（软代价）。"""
    penalty = 0.0
    for idx, (lo, hi) in limits.items():
        v = angles[idx]
        if v < lo:
            penalty += lo - v
        elif v > hi:
            penalty += v - hi
    return penalty


def limb_cost(parent, child, parent_name, child_name):
    cost = 25.0 * limit_penalty(parent, JOINT_LIMITS[parent_name])
    cost += limit_penalty(child, JOINT_LIMITS[child_name])
    cost += 0.02 * (abs(child[2]) + abs(parent[0]) + abs(parent[1]))
    return cost


def solve_limb(prox, dist, parent_name, child_name, flexion_sign):
    """父子两段肢体的双关节解（肩/肘、髋/膝）。

    父关节把静止段 (0,-1,0) 转到 prox 方向；沿骨轴扭转自由度 φ 扫描，选「关节限位
    代价最小」的解，使肘/膝成为单轴铰链（肘屈曲为负 rx、膝为正 rx），方向始终精确。
    flexion_sign：肘 = -1、膝 = +1。
    返回 (parent_angles, child_angles, cost)。
    """
    u = unit(prox)
    f = unit(dist)
    dot = float(np.clip(np.dot(u, f), -1.0, 1.0))
    beta = math.degrees(math.acos(dot))
    axis = np.cross(u, f)
    n = float(np.linalg.norm(axis))
    if n < 1e-6:
        # 两段共线：铰链轴不可观测，退化为最小扭转解 + 纯直关节。
        return solve_down(u), [0.0, 0.0, 0.0], 0.0
    h = axis / n * (1.0 if flexion_sign > 0 else -1.0)
    y_axis = -u
    R0 = np.column_stack([h, y_axis, np.cross(h, y_axis)])
    best = None
    for step in range(0, 360, 2):
        phi = -180.0 + step
        R = R0 @ rot_y(phi)
        parent = euler_from_matrix(R)
        child = solve_down(R.T @ f)
        cost = limb_cost(parent, child, parent_name, child_name)
        if best is None or cost < best[0]:
            best = (cost, parent, child)
    # 精确再扫一遍最优 φ 邻域（1° 步长）。
    _, parent0, child0 = best
    for step in range(0, 360):
        phi = -180.0 + step
        R = R0 @ rot_y(phi)
        parent = euler_from_matrix(R)
        child = solve_down(R.T @ f)
        cost = limb_cost(parent, child, parent_name, child_name)
        if cost < best[0] - 1e-9:
            best = (cost, parent, child)
    return best[1], best[2], best[0]


def solve_up(dir_up, dir_front):
    """由 (up, front) 两方向反解 Euler XYZ（头部/颈部）。"""
    u = unit(dir_up)
    f = dir_front - np.dot(dir_front, u) * u
    if np.linalg.norm(f) < 1e-6:
        f = np.array([0.0, 0.0, 1.0]) - np.dot(np.array([0.0, 0.0, 1.0]), u) * u
    f = unit(f)
    left = np.cross(u, f)
    R = np.column_stack([left, u, f])  # 列 = 目标基（left, up, front）
    sy = float(np.clip(R[0, 2], -1.0, 1.0))
    ry = math.degrees(math.asin(sy))
    rx = math.degrees(math.atan2(-R[1, 2], R[2, 2]))
    rz = math.degrees(math.atan2(-R[0, 1], R[0, 0]))
    return [rx, ry, rz]


def build_frame(world):
    """构造人体躯干坐标系：x=左（髋线）、y=上（髋中心→肩中心）、z=前。"""
    hip_l, hip_r = world[L['l_hip']], world[L['r_hip']]
    sho_l, sho_r = world[L['l_sho']], world[L['r_sho']]
    hip_c = (hip_l + hip_r) / 2.0
    sho_c = (sho_l + sho_r) / 2.0
    left = unit(hip_l - hip_r)
    up = unit(sho_c - hip_c)
    up = unit(up - np.dot(up, left) * left)
    front = unit(np.cross(left, up))
    return left, up, front, hip_c, sho_c


def to_body(v, frame):
    left, up, front = frame
    return np.array([float(np.dot(v, left)), float(np.dot(v, up)), float(np.dot(v, front))])


def clamp_joint(name, angles, clamps, pid):
    axes = {'rx': 0, 'ry': 1, 'rz': 2}
    base = name.split('_')[0]
    out = list(angles)
    for axis, idx in axes.items():
        lo, hi = -GENERIC_LIMIT, GENERIC_LIMIT
        if base in LIMITS and LIMITS[base][0] == idx:
            lo, hi = LIMITS[base][1], LIMITS[base][2]
        val = out[idx]
        if val < lo or val > hi:
            clamps.append({'id': pid, 'joint': name, 'axis': axis,
                           'from': round(val, 2), 'to': round(lo if val < lo else hi, 2)})
            out[idx] = lo if val < lo else hi
    return [round(v, 2) for v in out]


def derive(world, confidence, category=''):
    """核心推导：返回 joints/rootY/rootPitch/调试信息。"""
    left, up, front, hip_c, sho_c = build_frame(world)
    frame = (left, up, front)
    P = {k: world[i] for k, i in L.items()}

    def bd(a, b):
        return to_body(unit(P[b] - P[a]), frame)

    # --- 躯干 ---
    twist = math.degrees(math.atan2(
        float(np.dot(np.cross(left, unit(P['l_sho'] - P['r_sho'])), up)),
        float(np.dot(left, unit(P['l_sho'] - P['r_sho'])))))
    spine = [0.0, twist, 0.0]
    R_spine = euler_xyz(*spine)

    # --- 四肢 ---
    joints = {'spine': [0.0, round(twist, 2), 0.0]}

    for side, a_sho, a_elb, a_wri in (
            ('l', 'l_sho', 'l_elb', 'l_wri'), ('r', 'r_sho', 'r_elb', 'r_wri')):
        upper = bd(a_sho, a_elb)
        fore = bd(a_elb, a_wri)
        hand_dir = bd(a_wri, 'l_index' if side == 'l' else 'r_index')
        if not np.any(hand_dir):
            hand_dir = fore
        b_local = R_spine.T @ upper
        c_local = R_spine.T @ fore
        sho, elb, _cost = solve_limb(b_local, c_local, 'shoulder', 'elbow', -1.0)
        R_sho = euler_xyz(*sho)
        R_elb = euler_xyz(*elb)
        w_local = (R_sho @ R_elb).T @ hand_dir
        wri = solve_down(w_local)
        joints[f'shoulder_{side}'] = sho
        joints[f'elbow_{side}'] = elb
        joints[f'wrist_{side}'] = wri

    for side, a_hip, a_kne, a_ank in (
            ('l', 'l_hip', 'l_kne', 'l_ank'), ('r', 'r_hip', 'r_kne', 'r_ank')):
        thigh = bd(a_hip, a_kne)
        shin = bd(a_kne, a_ank)
        hip_angles, knee_angles, _cost = solve_limb(thigh, shin, 'hip', 'knee', 1.0)
        joints[f'hip_{side}'] = hip_angles
        joints[f'knee_{side}'] = knee_angles

    # --- 颈 ---
    ear_mid = (P['l_ear'] + P['r_ear']) / 2.0
    head_up = to_body(unit(ear_mid - sho_c), frame)
    head_front = to_body(unit(P['nose'] - ear_mid), frame)
    neck = solve_up(head_up, head_front)
    joints['neck'] = neck

    # --- rootPitch / rootY ---
    wu = float(np.dot(WORLD_UP, up))
    wf = float(np.dot(WORLD_UP, front))
    face_up = float(np.dot(unit(P['nose'] - ear_mid), WORLD_UP))
    if category == '躺姿':
        # 引擎 root 无 roll：躺姿按旧姿势库约定收敛为 ±88°（仰/侧卧 -88，俯卧 +88）。
        root_pitch = -88.0 if face_up >= 0 else 88.0
    else:
        root_pitch = max(-90.0, min(90.0, math.degrees(math.atan2(-wf, wu))))

    # 身体最低点（世界 y 向下取最大）到髋中心的高度 ≈ 站立髋高；引擎静止髋高 0.96 m
    # （person.js hipY = 0.96，qa 引擎默认身高 1.7 m），差值即 rootY。
    lowest_y = max(float(pt[1]) for pt in world)
    hip_y = float(hip_c[1])
    root_y = (lowest_y - hip_y) - ENGINE_HIP_HEIGHT
    root_y = max(ROOT_Y_MIN, min(ROOT_Y_MAX, root_y))
    return joints, root_pitch, root_y, {
        'head_up': head_up, 'head_front': head_front, 'twist': twist,
        'wu': wu, 'wf': wf, 'face_up': face_up,
    }


def pose_name(cat, joints, root_y, root_pitch, face_up=0.0):
    j = lambda n, a=0: joints[n][a]
    knee = (j('knee_l') + j('knee_r')) / 2.0
    elbow = (j('elbow_l') + j('elbow_r')) / 2.0
    sho_up = max(j('shoulder_l'), j('shoulder_r'))
    abd = max(abs(j('shoulder_l', 2)), abs(j('shoulder_r', 2)))
    hip_rz = (abs(j('hip_l', 2)) + abs(j('hip_r', 2))) / 2.0
    twist = j('spine', 1)
    neck_yaw = j('neck', 1)
    knee_diff = abs(j('knee_l') - j('knee_r'))
    if cat == '站姿':
        if sho_up > 120:
            return '站姿·举手伸展'
        if abd > 55:
            return '站姿·展臂'
        if knee > 22:
            return '站姿·半蹲重心'
        if abs(twist) > 18:
            return '站姿·转身回望'
        return '站姿·自然站立'
    if cat == '坐姿':
        if knee_diff > 22 or hip_rz > 18:
            return '坐姿·侧坐'
        if knee > 105:
            return '坐姿·端坐屈膝'
        return '坐姿·自然坐姿'
    if cat == '蹲姿':
        return '蹲姿·深蹲' if knee > 105 else '蹲姿·半蹲'
    if cat == '跪姿':
        return '跪姿·双膝跪地' if knee > 115 else '跪姿·单膝跪地'
    if cat == '靠姿':
        if abs(root_pitch) > 22:
            return '靠姿·侧身倚靠'
        return '靠姿·直立倚靠'
    if cat == '躺姿':
        if face_up > 0.35:
            return '躺姿·仰卧'
        if face_up < -0.35:
            return '躺姿·俯卧'
        return '躺姿·侧卧'
    if cat == '动态':
        if root_y > 0.12:
            return '动态·腾空跳跃'
        if max(abs(j('hip_l', 0)), abs(j('hip_r', 0))) > 60 and abd > 30:
            return '动态·舞动抬腿'
        if sho_up > 80:
            return '动态·跃起挥臂'
        return '动态·动态摆姿'
    if cat == '手部':
        if elbow < -110:
            return '手部·屈臂手势'
        if sho_up < -55:
            return '手部·举手示意'
        return '手部·自然手势'
    if cat == '神态':
        if abs(neck_yaw) > 18:
            return '神态·侧脸回眸'
        if neck_yaw > 6:
            return '神态·侧脸凝视'
        return '神态·正面肖像'
    if cat == '道具互动':
        if knee > 25:
            return '道具互动·倚物摆姿'
        if sho_up < -45 or abd > 40:
            return '道具互动·持物造型'
        return '道具互动·互动摆姿'
    if cat == '杂志大片':
        if sho_up > 110:
            return '杂志大片·举手定格'
        if abd > 50:
            return '杂志大片·展臂造型'
        if abs(twist) > 18 or abs(neck_yaw) > 12:
            return '杂志大片·侧身回眸'
        if hip_rz > 12:
            return '杂志大片·重心偏移'
        return '杂志大片·封面定格'
    if cat == '影视感':
        if abs(neck_yaw) > 18:
            return '影视感·侧脸凝视'
        if root_y > 0.05:
            return '影视感·俯身入戏'
        if sho_up < -40:
            return '影视感·倚坐沉思'
        return '影视感·正面定妆'
    return cat + '·参考'


def difficulty(joints, root_pitch, root_y):
    """与旧姿势库 gen_poses_v2._difficulty 同口径：max(|关节角|, |rootPitch|)。"""
    m = abs(root_pitch)
    for v in joints.values():
        for a in v:
            m = max(m, abs(a))
    if m < 28:
        return '新手友好'
    if m < 70:
        return '进阶'
    return '高难度'


CATEGORY_TIPS = {
    '站姿': ('双足均匀承重，重心落在髋部正下方', '手臂自然下垂，肩颈放松',
             '重心前移导致脚跟吃力'),
    '坐姿': ('坐骨均匀受力，上身保持中立', '手部自然搭放，避免耸肩', '含胸驼背、膝盖内扣'),
    '蹲姿': ('脚掌完全着地，膝盖与脚尖同向', '双臂放松或自然前伸保持平衡', '膝盖内扣、脚跟离地'),
    '跪姿': ('小腿与脚背贴地，重心稳定', '双手自然下垂或搭在腿上', '腰部塌陷、重心偏向一侧'),
    '靠姿': ('肩背贴合支撑面，单腿微曲承重', '手臂自然垂放，避免僵硬', '腰部悬空、身体过度后仰'),
    '躺姿': ('背部/侧面贴地，脊柱保持自然曲线', '手臂自然摊放，手腕放松', '颈部反折、腰部悬空'),
    '动态': ('起跳/舞动瞬间收紧核心，落地前脚掌缓冲', '手臂随动势摆动，手腕放松', '关节锁死、落地重心不稳'),
    '手部': ('手腕与前臂保持一条直线', '五指自然分开，避免过度用力', '手腕过度反折、手指僵硬'),
    '神态': ('下巴微收，视线与镜头方向一致', '面部放松，避免用力眯眼', '颈部前伸、下巴上扬'),
    '道具互动': ('身体与道具保持自然距离，重心稳', '持物手放松，腕部顺道具方向', '借力过多导致姿态失衡'),
    '杂志大片': ('重心偏移制造张力，肩线与髋线交错', '手部放松但指尖有指向，避免僵硬', '过度扭腰导致体态失真'),
    '影视感': ('情绪先于动作，肩颈放松、重心下沉', '手部自然入戏，避免摆拍感', '表情与姿态脱节、眼神涣散'),
}

CATEGORY_LENS = {
    '站姿': ('50mm 定焦（参考）', '腰部高度平视'),
    '坐姿': ('50mm 定焦（参考）', '坐姿视线同高'),
    '蹲姿': ('35mm（参考）', '蹲姿视线略低'),
    '跪姿': ('35mm（参考）', '膝盖高度略低'),
    '靠姿': ('50mm（参考）', '胸口高度平视'),
    '躺姿': ('35mm（参考）', '俯拍/贴地视角'),
    '动态': ('35mm 高速快门（参考）', '与胸部同高，预留动作空间'),
    '手部': ('85mm（参考）', '手部特写，光位柔和'),
    '神态': ('85mm 人像（参考）', '与眼睛同高'),
    '道具互动': ('50mm（参考）', '与胸口同高，带道具入画'),
    '杂志大片': ('85mm 人像（参考）', '与胸口同高，留出造型空间'),
    '影视感': ('50mm 电影感（参考）', '与眼睛同高，略带侧光位'),
}


def build(force=False, limit=0):
    manifest = read_json(MANIFEST, {})
    photos = manifest.get('photos', [])
    if not photos:
        print('[joints] 缺少 photos_manifest.json')
        return 2
    poses = []
    clamps = []
    skipped = []
    for entry in photos[:limit or None]:
        pid = entry['id']
        skel_path = os.path.join(PHOTOS_DIR, '%s.skeleton.json' % pid)
        data = read_json(skel_path, {})
        if not data.get('personDetected'):
            skipped.append(pid)
            continue
        world = [np.array(w, dtype=float) for w in data['world3d']]
        cat = entry['category']
        joints, root_pitch, root_y, dbg = derive(world, data.get('confidence', 0.0), cat)
        clean = {}
        for name in ('spine', 'neck',
                     'shoulder_l', 'elbow_l', 'wrist_l',
                     'shoulder_r', 'elbow_r', 'wrist_r',
                     'hip_l', 'knee_l', 'hip_r', 'knee_r'):
            clean[name] = clamp_joint(name, joints[name], clamps, pid)
        name = pose_name(cat, clean, root_y, root_pitch, dbg.get('face_up', 0.0))
        weight, hands, mistake = CATEGORY_TIPS.get(cat, CATEGORY_TIPS['站姿'])
        lens, camera = CATEGORY_LENS.get(cat, CATEGORY_LENS['站姿'])
        conf = float(data.get('confidence', 0.0))
        # 半身/特写照片标注（D68 存疑清单）：关键点纵向跨度异常时 3D 复现仅供参考。
        lm2d = data.get('landmarks2d', [])
        ys = [float(row[1]) for row in lm2d if len(row) > 1]
        span = (max(ys) - min(ys)) if ys else 0.0
        partial = span < 0.45 or span > 1.2
        poses.append({
            'id': pid,
            'name': name,
            'category': cat,
            'difficulty': difficulty(clean, root_pitch, root_y),
            'photo': entry['photo'],
            # 叠加图：assets 内 QA 证据（D66/R25 导出「骨架示意」可用），另保留 docs 相对路径。
            'overlay': entry['photo'].replace('.jpg', '.overlay.png'),
            'overlayRel': 'docs/pose-qa3/overlay-%s.png' % pid,
            'skeleton': entry['photo'].replace('.jpg', '.skeleton.json'),
            'confidence': round(conf, 4),
            'referenceOnly': conf < 0.6,
            'bodySpan': round(span, 3),
            'partialBody': partial,
            'partialReason': ('照片为半身/特写（关键点跨度 %.2f）' % span) if span < 0.45
                             else ('关键点跨度异常（%.2f），身体外推失真' % span) if partial else '',
            'joints': clean,
            'rootY': round(root_y, 3),
            'rootPitch': round(root_pitch, 2),
            'weight': weight,
            'hands': hands,
            'commonMistake': mistake,
            'lens': lens,
            'cameraPosition': camera,
            'source': entry.get('source', ''),
            'license': entry.get('license', ''),
            'author': entry.get('author', ''),
            'origin': entry.get('origin', ''),
        })
    payload = {
        'version': 1,
        'note': ('由 MediaPipe BlazePose world landmarks 推导（tool/skeleton_to_joints.py），'
                 '坐标为引擎 12 关节 Euler XYZ 角（度）；confidence<0.6 标记 referenceOnly（仅供构图参考）。'),
        'generator': 'tool/skeleton_to_joints.py',
        'total': len(poses),
        'poses': poses,
        'clamps': clamps,
    }
    os.makedirs(POSE_DIR, exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
    print('[joints] 写出 %d 条姿势（跳过无骨架 %d，限位夹取 %d）' % (len(poses), len(skipped), len(clamps)))
    cat_count = {}
    for p in poses:
        cat_count[p['category']] = cat_count.get(p['category'], 0) + 1
    print('[joints] 类目：%s' % json.dumps(cat_count, ensure_ascii=False))
    difficulty_count = {}
    for p in poses:
        difficulty_count[p['difficulty']] = difficulty_count.get(p['difficulty'], 0) + 1
    print('[joints] 难度：%s' % json.dumps(difficulty_count, ensure_ascii=False))
    ref = [p['id'] for p in poses if p['referenceOnly']]
    print('[joints] referenceOnly %d：%s' % (len(ref), ','.join(ref) if ref else '无'))
    return 0


def debug(pid):
    manifest = read_json(MANIFEST, {})
    entry = next((p for p in manifest.get('photos', []) if p['id'] == pid), None)
    if not entry:
        print('[debug] 未找到 %s' % pid)
        return 2
    data = read_json(os.path.join(PHOTOS_DIR, '%s.skeleton.json' % pid), {})
    world = [np.array(w, dtype=float) for w in data['world3d']]
    joints, root_pitch, root_y, dbg = derive(world, data.get('confidence', 0.0), entry['category'])
    print(json.dumps({'id': pid, 'category': entry['category'], 'confidence': data.get('confidence'),
                      'joints': {k: [round(x, 1) for x in v] for k, v in joints.items()},
                      'rootPitch': round(root_pitch, 1), 'rootY': round(root_y, 3),
                      'head_up': [round(float(x), 3) for x in dbg['head_up']],
                      'head_front': [round(float(x), 3) for x in dbg['head_front']],
                      'wu': round(dbg['wu'], 3), 'wf': round(dbg['wf'], 3),
                      'face_up': round(dbg['face_up'], 3),
                      'twist': round(dbg['twist'], 1)}, ensure_ascii=False, indent=2))
    return 0


def main():
    ap = argparse.ArgumentParser(description='world landmarks -> 12 关节角（poses3）')
    ap.add_argument('command', nargs='?', default='build', choices=['build', 'debug'])
    ap.add_argument('--force', action='store_true')
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--id', default='')
    args = ap.parse_args()
    if args.command == 'debug':
        return debug(args.id)
    return build(force=args.force, limit=args.limit)


if __name__ == '__main__':
    sys.exit(main())
