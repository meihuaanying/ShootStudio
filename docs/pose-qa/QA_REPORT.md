# 姿势 QA 报告（docs/pose-qa）

生成时间：2026-09-14T03:29:38.623Z

## 渲染方法

- 使用内置静态 HTTP 服务（127.0.0.1 随机端口）承载 app/ 资源，规避 file:// 下 fetch/GLB 外链限制；
- Edge headless（`--headless=new --use-angle=swiftshader --enable-unsafe-swiftshader`）经 CDP 截屏，视口 520×760（引擎图 640×900）；
- 姿势数据由 Node 读取 poses.json 并以查询参数传入 qa.html，逐条渲染正视图；golden 12 条渲染 4 视角；
- 截图总数：304（含 golden 4 视角与引擎人物图）。

## Golden 12（4 视角）

- pose-004：pose-004-v0.png、pose-004-v1.png、pose-004-v2.png、pose-004-v3.png
- pose-005：pose-005-v0.png、pose-005-v1.png、pose-005-v2.png、pose-005-v3.png
- pose-133：pose-133-v0.png、pose-133-v1.png、pose-133-v2.png、pose-133-v3.png
- pose-033：pose-033-v0.png、pose-033-v1.png、pose-033-v2.png、pose-033-v3.png
- pose-061：pose-061-v0.png、pose-061-v1.png、pose-061-v2.png、pose-061-v3.png
- pose-085：pose-085-v0.png、pose-085-v1.png、pose-085-v2.png、pose-085-v3.png
- pose-029：pose-029-v0.png、pose-029-v1.png、pose-029-v2.png、pose-029-v3.png
- pose-017：pose-017-v0.png、pose-017-v1.png、pose-017-v2.png、pose-017-v3.png
- pose-157：pose-157-v0.png、pose-157-v1.png、pose-157-v2.png、pose-157-v3.png
- pose-161：pose-161-v0.png、pose-161-v1.png、pose-161-v2.png、pose-161-v3.png
- pose-001：pose-001-v0.png、pose-001-v1.png、pose-001-v2.png、pose-001-v3.png
- pose-047：pose-047-v0.png、pose-047-v1.png、pose-047-v2.png、pose-047-v3.png

## 渲染批次

- m-casual-v0：成功 0，失败 18
- legacy-v0：成功 1
- f-casual-v0：成功 1
- qs-men-casual-v0：成功 1

## 截图清单（最终姿势）

| 姿势 | 正视图 | golden 4 视角 |
| --- | --- | --- |
| pose-001 自然站姿·正面 | pose-001.png | pose-001-v0.png<br>pose-001-v1.png<br>pose-001-v2.png<br>pose-001-v3.png |
| pose-002 自然站姿·左45° | pose-002.png | — |
| pose-003 自然站姿·右45° | pose-003.png | — |
| pose-004 自然站姿·背身回眸 | pose-004.png | pose-004-v0.png<br>pose-004-v1.png<br>pose-004-v2.png<br>pose-004-v3.png |
| pose-005 双手插兜·正面 | pose-005.png | pose-005-v0.png<br>pose-005-v1.png<br>pose-005-v2.png<br>pose-005-v3.png |
| pose-006 双手插兜·左45° | pose-006.png | — |
| pose-007 双手插兜·右45° | pose-007.png | — |
| pose-008 双手插兜·背身回眸 | pose-008.png | — |
| pose-009 单手叉腰·正面 | pose-009.png | — |
| pose-010 单手叉腰·左45° | pose-010.png | — |
| pose-011 单手叉腰·右45° | pose-011.png | — |
| pose-012 单手叉腰·背身回眸 | pose-012.png | — |
| pose-013 侧身回眸·正面 | pose-013.png | — |
| pose-014 侧身回眸·左45° | pose-014.png | — |
| pose-015 侧身回眸·右45° | pose-015.png | — |
| pose-016 侧身回眸·背身回眸 | pose-016.png | — |
| pose-017 双手抱臂·正面 | pose-017.png | pose-017-v0.png<br>pose-017-v1.png<br>pose-017-v2.png<br>pose-017-v3.png |
| pose-018 双手抱臂·左45° | pose-018.png | — |
| pose-019 双手抱臂·右45° | pose-019.png | — |
| pose-020 双手抱臂·背身回眸 | pose-020.png | — |
| pose-021 手扶帽檐·正面 | pose-021.png | — |
| pose-022 手扶帽檐·左45° | pose-022.png | — |
| pose-023 手扶帽檐·右45° | pose-023.png | — |
| pose-024 手扶帽檐·背身回眸 | pose-024.png | — |
| pose-025 双臂后展·正面 | pose-025.png | — |
| pose-026 双臂后展·左45° | pose-026.png | — |
| pose-027 双臂后展·右45° | pose-027.png | — |
| pose-028 双臂后展·背身回眸 | pose-028.png | — |
| pose-029 轻靠立姿·正面 | pose-029.png | pose-029-v0.png<br>pose-029-v1.png<br>pose-029-v2.png<br>pose-029-v3.png |
| pose-030 轻靠立姿·左45° | pose-030.png | — |
| pose-031 轻靠立姿·右45° | pose-031.png | — |
| pose-032 轻靠立姿·背身回眸 | pose-032.png | — |
| pose-033 椅上正坐·正面 | pose-033.png | pose-033-v0.png<br>pose-033-v1.png<br>pose-033-v2.png<br>pose-033-v3.png |
| pose-034 椅上正坐·左45° | pose-034.png | — |
| pose-035 椅上正坐·右45° | pose-035.png | — |
| pose-036 椅上正坐·背身回眸 | pose-036.png | — |
| pose-037 椅上侧坐·正面 | pose-037.png | — |
| pose-038 椅上侧坐·左45° | pose-038.png | — |
| pose-039 椅上侧坐·右45° | pose-039.png | — |
| pose-040 椅上侧坐·背身回眸 | pose-040.png | — |
| pose-041 前倾交谈·正面 | pose-041.png | — |
| pose-042 前倾交谈·左45° | pose-042.png | — |
| pose-043 前倾交谈·右45° | pose-043.png | — |
| pose-044 前倾交谈·背身回眸 | pose-044.png | — |
| pose-045 盘腿而坐·正面 | pose-045.png | — |
| pose-046 盘腿而坐·左45° | pose-046.png | — |
| pose-047 盘腿而坐·右45° | pose-047.png | pose-047-v0.png<br>pose-047-v1.png<br>pose-047-v2.png<br>pose-047-v3.png |
| pose-048 盘腿而坐·背身回眸 | pose-048.png | — |
| pose-049 席地抱膝·正面 | pose-049.png | — |
| pose-050 席地抱膝·左45° | pose-050.png | — |
| pose-051 席地抱膝·右45° | pose-051.png | — |
| pose-052 席地抱膝·背身回眸 | pose-052.png | — |
| pose-053 长椅舒展·正面 | pose-053.png | — |
| pose-054 长椅舒展·左45° | pose-054.png | — |
| pose-055 长椅舒展·右45° | pose-055.png | — |
| pose-056 长椅舒展·背身回眸 | pose-056.png | — |
| pose-057 边缘垂足·正面 | pose-057.png | — |
| pose-058 边缘垂足·左45° | pose-058.png | — |
| pose-059 边缘垂足·右45° | pose-059.png | — |
| pose-060 边缘垂足·背身回眸 | pose-060.png | — |
| pose-061 侧面深蹲·正面 | pose-061.png | pose-061-v0.png<br>pose-061-v1.png<br>pose-061-v2.png<br>pose-061-v3.png |
| pose-062 侧面深蹲·左45° | pose-062.png | — |
| pose-063 侧面深蹲·右45° | pose-063.png | — |
| pose-064 侧面深蹲·背身回眸 | pose-064.png | — |
| pose-065 单膝点地·正面 | pose-065.png | — |
| pose-066 单膝点地·左45° | pose-066.png | — |
| pose-067 单膝点地·右45° | pose-067.png | — |
| pose-068 单膝点地·背身回眸 | pose-068.png | — |
| pose-069 蹲姿抬头·正面 | pose-069.png | — |
| pose-070 蹲姿抬头·左45° | pose-070.png | — |
| pose-071 蹲姿抬头·右45° | pose-071.png | — |
| pose-072 蹲姿抬头·背身回眸 | pose-072.png | — |
| pose-073 蹲姿托腮·正面 | pose-073.png | — |
| pose-074 蹲姿托腮·左45° | pose-074.png | — |
| pose-075 蹲姿托腮·右45° | pose-075.png | — |
| pose-076 蹲姿托腮·背身回眸 | pose-076.png | — |
| pose-077 侧蹲延伸·正面 | pose-077.png | — |
| pose-078 侧蹲延伸·左45° | pose-078.png | — |
| pose-079 侧蹲延伸·右45° | pose-079.png | — |
| pose-080 侧蹲延伸·背身回眸 | pose-080.png | — |
| pose-081 蹲姿背身·正面 | pose-081.png | — |
| pose-082 蹲姿背身·左45° | pose-082.png | — |
| pose-083 蹲姿背身·右45° | pose-083.png | — |
| pose-084 蹲姿背身·背身回眸 | pose-084.png | — |
| pose-085 双膝跪坐·正面 | pose-085.png | pose-085-v0.png<br>pose-085-v1.png<br>pose-085-v2.png<br>pose-085-v3.png |
| pose-086 双膝跪坐·左45° | pose-086.png | — |
| pose-087 双膝跪坐·右45° | pose-087.png | — |
| pose-088 双膝跪坐·背身回眸 | pose-088.png | — |
| pose-089 单膝跪地·正面 | pose-089.png | — |
| pose-090 单膝跪地·左45° | pose-090.png | — |
| pose-091 单膝跪地·右45° | pose-091.png | — |
| pose-092 单膝跪地·背身回眸 | pose-092.png | — |
| pose-093 跪姿后仰·正面 | pose-093.png | — |
| pose-094 跪姿后仰·左45° | pose-094.png | — |
| pose-095 跪姿后仰·右45° | pose-095.png | — |
| pose-096 跪姿后仰·背身回眸 | pose-096.png | — |
| pose-097 跪姿前俯·正面 | pose-097.png | — |
| pose-098 跪姿前俯·左45° | pose-098.png | — |
| pose-099 跪姿前俯·右45° | pose-099.png | — |
| pose-100 跪姿前俯·背身回眸 | pose-100.png | — |
| pose-101 侧跪支撑·正面 | pose-101.png | — |
| pose-102 侧跪支撑·左45° | pose-102.png | — |
| pose-103 侧跪支撑·右45° | pose-103.png | — |
| pose-104 侧跪支撑·背身回眸 | pose-104.png | — |
| pose-105 跪姿回望·正面 | pose-105.png | — |
| pose-106 跪姿回望·左45° | pose-106.png | — |
| pose-107 跪姿回望·右45° | pose-107.png | — |
| pose-108 跪姿回望·背身回眸 | pose-108.png | — |
| pose-109 靠墙单腿·正面 | pose-109.png | — |
| pose-110 靠墙单腿·左45° | pose-110.png | — |
| pose-111 靠墙单腿·右45° | pose-111.png | — |
| pose-112 靠墙单腿·背身回眸 | pose-112.png | — |
| pose-113 靠栏远望·正面 | pose-113.png | — |
| pose-114 靠栏远望·左45° | pose-114.png | — |
| pose-115 靠栏远望·右45° | pose-115.png | — |
| pose-116 靠栏远望·背身回眸 | pose-116.png | — |
| pose-117 背靠站立·正面 | pose-117.png | — |
| pose-118 背靠站立·左45° | pose-118.png | — |
| pose-119 背靠站立·右45° | pose-119.png | — |
| pose-120 背靠站立·背身回眸 | pose-120.png | — |
| pose-121 侧肩靠墙·正面 | pose-121.png | — |
| pose-122 侧肩靠墙·左45° | pose-122.png | — |
| pose-123 侧肩靠墙·右45° | pose-123.png | — |
| pose-124 侧肩靠墙·背身回眸 | pose-124.png | — |
| pose-125 靠树低首·正面 | pose-125.png | — |
| pose-126 靠树低首·左45° | pose-126.png | — |
| pose-127 靠树低首·右45° | pose-127.png | — |
| pose-128 靠树低首·背身回眸 | pose-128.png | — |
| pose-129 倚靠放松·正面 | pose-129.png | — |
| pose-130 倚靠放松·左45° | pose-130.png | — |
| pose-131 倚靠放松·右45° | pose-131.png | — |
| pose-132 倚靠放松·背身回眸 | pose-132.png | — |
| pose-133 平躺舒展·仰卧 | pose-133.png | pose-133-v0.png<br>pose-133-v1.png<br>pose-133-v2.png<br>pose-133-v3.png |
| pose-134 平躺舒展·左侧卧 | pose-134.png | — |
| pose-135 平躺舒展·右侧卧 | pose-135.png | — |
| pose-136 平躺舒展·俯卧回望 | pose-136.png | — |
| pose-137 侧躺曲臂·仰卧 | pose-137.png | — |
| pose-138 侧躺曲臂·左侧卧 | pose-138.png | — |
| pose-139 侧躺曲臂·右侧卧 | pose-139.png | — |
| pose-140 侧躺曲臂·俯卧回望 | pose-140.png | — |
| pose-141 趴伏抬头·仰卧 | pose-141.png | — |
| pose-142 趴伏抬头·左侧卧 | pose-142.png | — |
| pose-143 趴伏抬头·右侧卧 | pose-143.png | — |
| pose-144 趴伏抬头·俯卧回望 | pose-144.png | — |
| pose-145 躺姿伸腿·仰卧 | pose-145.png | — |
| pose-146 躺姿伸腿·左侧卧 | pose-146.png | — |
| pose-147 躺姿伸腿·右侧卧 | pose-147.png | — |
| pose-148 躺姿伸腿·俯卧回望 | pose-148.png | — |
| pose-149 蜷缩侧卧·仰卧 | pose-149.png | — |
| pose-150 蜷缩侧卧·左侧卧 | pose-150.png | — |
| pose-151 蜷缩侧卧·右侧卧 | pose-151.png | — |
| pose-152 蜷缩侧卧·俯卧回望 | pose-152.png | — |
| pose-153 仰卧屈膝·仰卧 | pose-153.png | — |
| pose-154 仰卧屈膝·左侧卧 | pose-154.png | — |
| pose-155 仰卧屈膝·右侧卧 | pose-155.png | — |
| pose-156 仰卧屈膝·俯卧回望 | pose-156.png | — |
| pose-157 行走瞬间·正面 | pose-157.png | pose-157-v0.png<br>pose-157-v1.png<br>pose-157-v2.png<br>pose-157-v3.png |
| pose-158 行走瞬间·左前进 | pose-158.png | — |
| pose-159 行走瞬间·右前进 | pose-159.png | — |
| pose-160 行走瞬间·背身 | pose-160.png | — |
| pose-161 小跑前进·正面 | pose-161.png | pose-161-v0.png<br>pose-161-v1.png<br>pose-161-v2.png<br>pose-161-v3.png |
| pose-162 小跑前进·左前进 | pose-162.png | — |
| pose-163 小跑前进·右前进 | pose-163.png | — |
| pose-164 小跑前进·背身 | pose-164.png | — |
| pose-165 跳起悬空·正面 | pose-165.png | — |
| pose-166 跳起悬空·左前进 | pose-166.png | — |
| pose-167 跳起悬空·右前进 | pose-167.png | — |
| pose-168 跳起悬空·背身 | pose-168.png | — |
| pose-169 旋转回身·正面 | pose-169.png | — |
| pose-170 旋转回身·左前进 | pose-170.png | — |
| pose-171 旋转回身·右前进 | pose-171.png | — |
| pose-172 旋转回身·背身 | pose-172.png | — |
| pose-173 腾空劈叉·正面 | pose-173.png | — |
| pose-174 腾空劈叉·左前进 | pose-174.png | — |
| pose-175 腾空劈叉·右前进 | pose-175.png | — |
| pose-176 腾空劈叉·背身 | pose-176.png | — |
| pose-177 前倾冲刺·正面 | pose-177.png | — |
| pose-178 前倾冲刺·左前进 | pose-178.png | — |
| pose-179 前倾冲刺·右前进 | pose-179.png | — |
| pose-180 前倾冲刺·背身 | pose-180.png | — |
| pose-181 接物伸展·正面 | pose-181.png | — |
| pose-182 接物伸展·左前进 | pose-182.png | — |
| pose-183 接物伸展·右前进 | pose-183.png | — |
| pose-184 接物伸展·背身 | pose-184.png | — |
| pose-185 挥手致意·正面 | pose-185.png | — |
| pose-186 挥手致意·左45° | pose-186.png | — |
| pose-187 挥手致意·右45° | pose-187.png | — |
| pose-188 挥手致意·背身回眸 | pose-188.png | — |
| pose-189 指向远方·正面 | pose-189.png | — |
| pose-190 指向远方·左45° | pose-190.png | — |
| pose-191 指向远方·右45° | pose-191.png | — |
| pose-192 指向远方·背身回眸 | pose-192.png | — |
| pose-193 手托下巴·正面 | pose-193.png | — |
| pose-194 手托下巴·左45° | pose-194.png | — |
| pose-195 手托下巴·右45° | pose-195.png | — |
| pose-196 手托下巴·背身回眸 | pose-196.png | — |
| pose-197 手扶锁骨·正面 | pose-197.png | — |
| pose-198 手扶锁骨·左45° | pose-198.png | — |
| pose-199 手扶锁骨·右45° | pose-199.png | — |
| pose-200 手扶锁骨·背身回眸 | pose-200.png | — |
| pose-201 双手合拢·正面 | pose-201.png | — |
| pose-202 双手合拢·左45° | pose-202.png | — |
| pose-203 双手合拢·右45° | pose-203.png | — |
| pose-204 双手合拢·背身回眸 | pose-204.png | — |
| pose-205 手撩发丝·正面 | pose-205.png | — |
| pose-206 手撩发丝·左45° | pose-206.png | — |
| pose-207 手撩发丝·右45° | pose-207.png | — |
| pose-208 手撩发丝·背身回眸 | pose-208.png | — |
| pose-209 低头沉思·正面 | pose-209.png | — |
| pose-210 低头沉思·左45° | pose-210.png | — |
| pose-211 低头沉思·右45° | pose-211.png | — |
| pose-212 低头沉思·背身回眸 | pose-212.png | — |
| pose-213 仰头望天·正面 | pose-213.png | — |
| pose-214 仰头望天·左45° | pose-214.png | — |
| pose-215 仰头望天·右45° | pose-215.png | — |
| pose-216 仰头望天·背身回眸 | pose-216.png | — |
| pose-217 侧颜凝视·正面 | pose-217.png | — |
| pose-218 侧颜凝视·左45° | pose-218.png | — |
| pose-219 侧颜凝视·右45° | pose-219.png | — |
| pose-220 侧颜凝视·背身回眸 | pose-220.png | — |
| pose-221 半回头·正面 | pose-221.png | — |
| pose-222 半回头·左45° | pose-222.png | — |
| pose-223 半回头·右45° | pose-223.png | — |
| pose-224 半回头·背身回眸 | pose-224.png | — |
| pose-225 含胸收拢·正面 | pose-225.png | — |
| pose-226 含胸收拢·左45° | pose-226.png | — |
| pose-227 含胸收拢·右45° | pose-227.png | — |
| pose-228 含胸收拢·背身回眸 | pose-228.png | — |
| pose-229 舒展挺胸·正面 | pose-229.png | — |
| pose-230 舒展挺胸·左45° | pose-230.png | — |
| pose-231 舒展挺胸·右45° | pose-231.png | — |
| pose-232 舒展挺胸·背身回眸 | pose-232.png | — |
| pose-233 撑伞而立·正面 | pose-233.png | — |
| pose-234 撑伞而立·左45° | pose-234.png | — |
| pose-235 撑伞而立·右45° | pose-235.png | — |
| pose-236 撑伞而立·背身回眸 | pose-236.png | — |
| pose-237 举花轻嗅·正面 | pose-237.png | — |
| pose-238 举花轻嗅·左45° | pose-238.png | — |
| pose-239 举花轻嗅·右45° | pose-239.png | — |
| pose-240 举花轻嗅·背身回眸 | pose-240.png | — |
| pose-241 手持相机·正面 | pose-241.png | — |
| pose-242 手持相机·左45° | pose-242.png | — |
| pose-243 手持相机·右45° | pose-243.png | — |
| pose-244 手持相机·背身回眸 | pose-244.png | — |
| pose-245 背包单肩·正面 | pose-245.png | — |
| pose-246 背包单肩·左45° | pose-246.png | — |
| pose-247 背包单肩·右45° | pose-247.png | — |
| pose-248 背包单肩·背身回眸 | pose-248.png | — |
| pose-249 抱琴而立·正面 | pose-249.png | — |
| pose-250 抱琴而立·左45° | pose-250.png | — |
| pose-251 抱琴而立·右45° | pose-251.png | — |
| pose-252 抱琴而立·背身回眸 | pose-252.png | — |
| pose-253 扶帽侧身·正面 | pose-253.png | — |
| pose-254 扶帽侧身·左45° | pose-254.png | — |
| pose-255 扶帽侧身·右45° | pose-255.png | — |
| pose-256 扶帽侧身·背身回眸 | pose-256.png | — |

> 被裁姿势的原始截图仍保留在 docs/pose-qa/ 作为校对证据。