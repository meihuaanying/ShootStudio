#!/usr/bin/env python3
"""生成 Dart 拼音字典（R46 兜底：未命中词表且 AI 不可用时，中文转拼音再检索）。

语料 = 画面词表键 + 内置内容资产（姿势/预设/器材/模板/城市等）中出现的全部
汉字，去重后用 pypinyin 生成无声调拼音，输出 `lib/services/search/pinyin_data.dart`。

用法：python tool/gen_pinyin_dict.py
依赖：pip install pypinyin
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CJK = re.compile(r"[\u4e00-\u9fff]")
OUT = ROOT / "lib" / "services" / "search" / "pinyin_data.dart"


def collect_chars() -> set[str]:
    chars: set[str] = set()

    def feed(text: str) -> None:
        chars.update(CJK.findall(text))

    # 1) 画面词表键
    feed((ROOT / "lib" / "services" / "image_sources.dart").read_text("utf-8"))
    # 2) 搜索服务（主题包/人名表等）
    search_dir = ROOT / "lib" / "services" / "search"
    if search_dir.exists():
        for path in sorted(search_dir.glob("*.dart")):
            if path.name == "pinyin_data.dart":
                continue
            feed(path.read_text("utf-8"))
    # 3) 内置内容资产
    for path in sorted((ROOT / "assets" / "content").rglob("*.json")):
        try:
            feed(path.read_text("utf-8"))
        except Exception:
            continue
    # 4) 常见高频字补充（用户自由输入兜底）
    feed(
        "我你他她它们这那哪个是什么在哪里怎么为如何想找要看去拍照片人像风景"
        "电影动漫动画剧集画作绘画摄影参考逆光夜景城市街道海边森林山湖雪雨"
        "春夏秋冬清晨黄昏日落日出温柔安静热烈复古未来科幻梦幻童话校园课堂"
        "办公室咖啡店酒吧餐厅厨房卧室客厅花园公园博物馆美术馆图书馆运动健身"
        "舞蹈音乐乐器服装汉服旗袍和服婚纱礼服西装校服制服运动装街头风格色彩"
        "冷暖黑白青橙莫兰迪马卡龙构图角度俯拍仰拍特写全身半身情侣亲子闺蜜单"
        "双多人儿童老人男生女生东方亚洲欧美韩系日系港风民国昭和千禧极简巴洛"
        "克哥特浪漫神秘惊悚奇幻机甲面具珠宝帽子墨镜婚礼毕业孕期骑马宠物猫狗"
        "美食咖啡杯书阅读写字弹琴吉他钢琴小提琴大提琴唱歌跳舞跑步游泳骑车"
        "开车旅行露营野餐烧烤篝火烟花灯笼烛光霓虹灯牌雨伞镜子玻璃水面倒影"
        "星际穿越际遇国际实际继承继续纪录纪念季节世纪世界界线限制制度制作"
        "梵高向日葵葵花盛开开放时刻雕刻雕塑塑像像片片段段落落地地球球场"
        "海诚诚实诚恳恳切切身体体验验证证明明星星球球队队员员工厂商业业务"
        "王家卫卫生生活活动动作作家家庭庭院院子女子男孩孩童年华岁月月光"
        "黑泽明泽沼沼泽洋大海海洋洋溢溢出出来来回回忆记忆忆苦思甜甜蜜"
        "宫崎骏崎岖岖路骏马马车车间间隔隔壁壁画画廊廊桥桥梁梁朝伟朝霞"
        "张艺谋谋划划船船长长夜夜晚晚安安排排练练习习惯惯例例如如果果实"
        "斯皮尔伯格皮尔斯尔虞我诈诈欺骗骗局局面面条条件件数数据根据据说"
        "卡梅隆梅兰竹菊兰花花朵朵朵云云彩彩虹虹桥桥段段落实况况味味道"
        "昆汀塔伦蒂诺伦勃朗勃然大怒怒气气质朴朴素素材材料预料料理事"
        "毕加索加索引引擎挚爱爱情情感感受受伤伤害害怕恐惧惧怕怯场场地"
        "达芬奇奇妙妙趣趣味味道理化学生活证明明白白天天空空气气息媳妇"
        "米开朗基罗开朗朗诵诵读读书书本本来来历历程程度度过过程程序"
        "马蒂斯光滑滑板板块块头头脑脑海海军军队队伍伍长长久久久远"
        "塞尚高尚尚且而且而后后悔悔改改变变化化学学习习题题目目录"
        "高更更换换算算术术语语言言论论文文件件物品品牌牌牌照照片"
        "雷诺阿诺言言语言辞辞职职位位置置办办事事情情况况且且慢"
        "德加加油油画画家家具具备备份份额额外外表表现现实实在"
        "克里姆特特别别扭扭曲曲线线条条款款式样式样子子孙"
        "蒙克克服服气气候候鸟鸟巢巢穴穴位位置置换幻想想象"
        "维米尔尔后后代代表表演演出出版版本本子子女女儿"
        "葛饰北斋装饰饰品品种种类类别别墅墅园园林"
        "浮世绘世间间隔隔壁壁纸纸张张开开心"
        "齐白石石头头脑脑袋袋鼠鼠年年度度数"
        "张大千千万万分之一一切切割割舍"
        "徐悲鸿悲哀哀伤伤口口才才能能力"
        "八大山人山山脉脉络络绎不绝"
    )
    return chars


def main() -> int:
    try:
        from pypinyin import lazy_pinyin
    except ImportError:
        print("请先安装 pypinyin：pip install pypinyin", file=sys.stderr)
        return 1
    chars = sorted(collect_chars())
    entries: list[tuple[str, str]] = []
    for ch in chars:
        py = lazy_pinyin(ch)
        if not py:
            continue
        value = py[0]
        if value == ch or not value.isascii():
            continue
        entries.append((ch, value.lower()))
    lines = [
        "// 由 tool/gen_pinyin_dict.py 生成，勿手改。",
        "// R46 兜底：未命中词表且 AI 不可用时，中文按字转拼音再检索。",
        "",
        "const Map<String, String> kPinyinDict = <String, String>{",
    ]
    for ch, py in entries:
        lines.append(f"  '{ch}': '{py}',")
    lines.append("};")
    lines.append("")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"生成 {len(entries)} 条 → {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
