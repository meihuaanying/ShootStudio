"""Q1b 写实角色生成（D61，最高标准路线）：MakeHuman 官方资产 + MPFB2（MakeHuman 官方 Blender 集成）

管线：
  1. MakeHuman Community 官方资产包 makehuman_system_assets（CC0）解包到 MPFB2 用户数据目录：
     <blender_ext_user>/mpfb/data/{clothes,eyes,eyebrows,eyelashes,teeth,tongue,skins,hair,packs}
  2. Blender 4.5 无头（--background）加载 MPFB2 扩展 bl_ext.user_default.mpfb：
     create_human（MakeHuman base mesh，19k 顶点）→ 宏参数（性别/年龄/肌肉/身高/人种）
     → 皮肤 .mhmat → 系统资产（眼/眉/睫毛/牙/舌，.mhclo）→ 服装 + 头发（.mhclo）
     → game_engine 骨骼（53 骨，含上身/下肢/手指）→ 导出 GLB（应用 MASK 修改器，避免穿模）
  3. 输出写实 GLB + 三角面数/骨骼清单报告（JSON）

用法（工作目录 app/，或任意目录；路径均可用绝对路径）：
  <blender.exe> --background --python tool/gen_realistic_character.py -- \
      --out  assets/models/characters/realistic/mh-men-01.glb \
      --report docs/screenshots/realistic-build-report.json \
      --gender male --outfit male_casualsuit02 --hair short01 --skin young_caucasian_male

依赖：MPFB2 扩展（%APPDATA%/Blender Foundation/Blender/4.5/extensions/user_default/mpfb）
      与 makehuman_system_assets 资产包（tool/doh.py 可辅助下载）。
"""
import argparse
import importlib
import json
import os
import re
import sys
import traceback

import bpy


def dynamic_import(absolute_package_str, key):
    """MPFB2 官方脚本惯例：Blender 扩展包名不确定，按后缀在 sys.modules 中查找。"""
    for amod in sys.modules:
        if amod.endswith(absolute_package_str):
            mpfb_mod = importlib.import_module(amod)
            if not hasattr(mpfb_mod, key):
                raise AttributeError(f"Module {amod} does not have attribute {key}")
            return getattr(mpfb_mod, key)
    raise ValueError(f"No module found with name ending in {absolute_package_str}")


HumanService = None
AssetService = None
TargetService = None
HumanObjectProperties = None


def bind_services():
    global HumanService, AssetService, TargetService, HumanObjectProperties
    HumanService = dynamic_import("mpfb.services.humanservice", "HumanService")
    AssetService = dynamic_import("mpfb.services.assetservice", "AssetService")
    TargetService = dynamic_import("mpfb.services.targetservice", "TargetService")
    HumanObjectProperties = dynamic_import("mpfb.entities.objectproperties", "HumanObjectProperties")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser(prog="gen_realistic_character")
    p.add_argument("--out", required=True, help="输出 GLB 路径")
    p.add_argument("--report", default="", help="构建报告 JSON 路径")
    p.add_argument("--gender", default="male", choices=["male", "female"])
    p.add_argument("--outfit", default="", help="服装 .mhclo 目录名（data/clothes/<name>）")
    p.add_argument("--outfit2", default="", help="第二层服装（可选，用于叠加面数）")
    p.add_argument("--hair", default="", help="头发 .mhclo 目录名（data/hair/<name>）")
    p.add_argument("--skin", default="", help="皮肤 .mhmat 名（data/skins/<race>/<name>.mhmat）")
    p.add_argument("--age", type=float, default=0.45)
    p.add_argument("--muscle", type=float, default=0.55)
    p.add_argument("--weight", type=float, default=0.5)
    p.add_argument("--height", type=float, default=0.55)
    p.add_argument("--subdiv", type=int, default=0, help="身体细分级别（0=不细分；1=4 倍面数）")
    p.add_argument("--subdiv-body", type=int, default=0, help="仅对身体网格施加细分级别（写实模式运行时不再细分，故构建期提升密度）")
    p.add_argument("--eyes", default="low-poly", choices=["low-poly", "high-poly"], help="眼球 mhclo 规格")
    p.add_argument("--image-quality", type=int, default=80, help="GLB 贴图 JPEG 质量（R22 包体预算）")
    p.add_argument("--tex-max", type=int, default=1024, help="贴图最大边长（0=不缩放）")
    p.add_argument("--tex-png", action="store_true", help="保留 PNG（默认转 JPEG 以压缩包体）")
    p.add_argument("--image-format", default="JPEG", choices=["AUTO", "JPEG", "WEBP", "NONE"], help="GLB 贴图格式")
    p.add_argument("--min-tris", type=int, default=0, help="若总面数低于该值且允许细分，自动细分身体 1 级")
    p.add_argument("--no-rig", action="store_true")
    return p.parse_args(argv)


def set_macros(human, args, gender_value):
    values = {
        "gender": gender_value,
        "age": args.age,
        "muscle": args.muscle,
        "weight": args.weight,
        "height": args.height,
        "proportions": 0.5,
        "african": 0.0,
        "asian": 0.0,
        "caucasian": 1.0,
    }
    for key, value in values.items():
        try:
            HumanObjectProperties.set_value(key, value, entity_reference=human)
        except Exception as exc:  # 某些宏在旧版本不存在，不阻塞
            print(f"[gen-real] macro skip {key}: {exc}")
    TargetService.reapply_macro_details(human)


def find_asset(filename, subdir):
    path = AssetService.find_asset_absolute_path(filename, asset_subdir=subdir)
    if path and os.path.exists(path):
        return path
    print(f"[gen-real] asset not found: {subdir}/{filename}")
    return None


def add_system_assets(human, eyes_spec="low-poly"):
    """眼/眉/睫毛/牙/舌：MPFB2 官方示例 06_adding_basic_assets.py 的等价调用。"""
    assets = [
        ("eyes", f"{eyes_spec}.mhclo", "Eyes"),
        ("eyebrows", "eyebrow001.mhclo", "Eyebrows"),
        ("eyelashes", "eyelashes01.mhclo", "Eyelashes"),
        ("tongue", "tongue01.mhclo", "Tongue"),
        ("teeth", "teeth_base.mhclo", "Teeth"),
    ]
    added = []
    for subdir, filename, asset_type in assets:
        path = find_asset(filename, subdir)
        if not path:
            continue
        try:
            obj = HumanService.add_mhclo_asset(path, human, asset_type=asset_type)
            added.append({"asset": f"{subdir}/{filename}", "type": asset_type, "object": obj.name if obj else None})
        except Exception as exc:
            print(f"[gen-real] add asset failed {subdir}/{filename}: {exc}")
    return added


def add_mhclo_dir(human, kind, name, asset_type):
    """加载 data/<kind>/<name>/<name>.mhclo（服装/头发/鞋）。"""
    if not name:
        return None
    path = find_asset(f"{name}.mhclo", kind)
    if not path:
        return None
    try:
        obj = HumanService.add_mhclo_asset(path, human, asset_type=asset_type)
        return {"asset": f"{kind}/{name}", "type": asset_type, "object": obj.name if obj else None}
    except Exception as exc:
        print(f"[gen-real] add {kind}/{name} failed: {exc}")
        return None


def apply_skin(human, args, gender):
    if not args.skin:
        return None
    mhmat = find_asset(f"{args.skin}.mhmat", "skins")
    if not mhmat:
        return None
    try:
        HumanService.set_character_skin(mhmat, human, skin_type="MAKESKIN")
        return os.path.basename(mhmat)
    except Exception as exc:
        print(f"[gen-real] skin failed: {exc}")
        return None


def triangle_count(mesh_obj):
    mesh = mesh_obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def evaluated_triangle_count(mesh_obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    ev = mesh_obj.evaluated_get(depsgraph)
    me = ev.to_mesh()
    me.calc_loop_triangles()
    count = len(me.loop_triangles)
    ev.to_mesh_clear()
    return count


def optimize_textures(max_size, as_jpeg, quality):
    """R22 包体预算：限制贴图边长并转为 JPEG（写实模式 diffuse/normal 均不需要 alpha）。"""
    import tempfile
    report = []
    tmpdir = tempfile.mkdtemp(prefix="ss_realistic_tex_")
    for img in list(bpy.data.images):
        if img.type != "IMAGE" or img.source not in ("FILE", "GENERATED", "SEQUENCE"):
            continue
        try:
            if not img.has_data:
                img.reload()
        except Exception:
            pass
        if not img.has_data:
            try:
                _ = img.pixels[0]
            except Exception:
                pass
        if not img.has_data:
            print(f"[gen-real] texture not loaded, skipped: {img.name} ({img.filepath})")
            continue
        src_w, src_h = img.size
        if not src_w or not src_h:
            continue
        try:
            if max_size and max(src_w, src_h) > max_size:
                scale = max_size / max(src_w, src_h)
                img.scale(max(16, int(src_w * scale)), max(16, int(src_h * scale)))
            if as_jpeg:
                path = os.path.join(tmpdir, f"{img.name}.jpg")
                img.filepath_raw = path
                img.file_format = "JPEG"
                img.save()
                img.filepath = path
                img.reload()
            report.append({"name": img.name, "from": [src_w, src_h],
                           "to": [img.size[0], img.size[1]], "jpeg": bool(as_jpeg)})
        except Exception as exc:
            print(f"[gen-real] texture optimize skip {img.name}: {exc}")
    return report


def normalize_material_blend():
    """MPFB2 的 mhmat 材质导出后一律是 glTF alphaMode=BLEND，但 BLEND 会让不透明网格
    （皮肤/服装/眼球/牙）在 three.js 中走透明排序，出现「看穿嘴唇见到口腔/眼球内壁」的错误观感。
    仅对确实需要 alpha 的资产（睫毛/眉毛/头发）保留透明，其余把 Principled BSDF 的 Alpha 断开并置 1.0，
    使 glTF 导出为 OPAQUE。Blender 4.2+ 已移除 Material.blend_method，故按节点树处理。"""
    keep_alpha = re.compile(r"eyelash|eyebrow|hair|short\d|bob\d|long\d|ponytail|afro|braid", re.I)
    report = []
    materials = set()
    for ob in bpy.data.objects:
        if ob.type != "MESH":
            continue
        needs_alpha = bool(keep_alpha.search(ob.name))
        for slot in ob.material_slots:
            if slot.material:
                materials.add((slot.material, needs_alpha))
    for mat, needs_alpha in materials:
        if not mat.use_nodes or not mat.node_tree:
            continue
        changed = []
        if hasattr(mat, "blend_method"):
            target = "BLEND" if needs_alpha else "OPAQUE"
            if mat.blend_method != target:
                mat.blend_method = target
                changed.append("blend_method")
        if hasattr(mat, "surface_render_method"):
            target = "BLENDED" if needs_alpha else "DITHERED"
            if mat.surface_render_method != target:
                mat.surface_render_method = target
                changed.append("surface_render_method")
        if not needs_alpha:
            for node in mat.node_tree.nodes:
                if node.type != "BSDF_PRINCIPLED":
                    continue
                alpha = node.inputs.get("Alpha")
                if not alpha:
                    continue
                for link in list(alpha.links):
                    mat.node_tree.links.remove(link)
                    changed.append("alpha_unlink")
                if alpha.default_value != 1.0:
                    alpha.default_value = 1.0
                    changed.append("alpha=1")
        if changed:
            report.append({"material": mat.name, "changes": changed})
    return report


def main():
    args = parse_args()
    report = {"args": vars(args)}
    try:
        bind_services()

        bpy.ops.wm.read_factory_settings(use_empty=True)
        gender_value = 1.0 if args.gender == "female" else 0.0
        human = HumanService.create_human(scale=0.1)
        print("[gen-real] human created:", human.name, "verts", len(human.data.vertices))
        set_macros(human, args, gender_value)
        report["skin"] = apply_skin(human, args, args.gender)

        # 重要：骨骼必须先于资产/服装建立——MPFB2 的 add_mhclo_asset 通过
        # find_object_of_type_amongst_nearest_relatives(basemesh, "Skeleton") 查找已有骨架来绑权重；
        # 先加服装会得到「无蒙皮」网格（GLB 里 skin=None），姿势驱动时服装不跟随。
        if not args.no_rig:
            arm = HumanService.add_builtin_rig(human, "game_engine", import_weights=True)
            report["rig"] = {
                "name": arm.name if arm else None,
                "bones": [b.name for b in arm.data.bones] if arm else [],
            }
            print("[gen-real] rig:", arm.name if arm else None, "bones:", len(arm.data.bones) if arm else 0)
        else:
            report["rig"] = None

        report["system_assets"] = add_system_assets(human, args.eyes)

        wheels = [
            {"kind": "clothes", "name": args.outfit, "type": "Clothes"},
            {"kind": "clothes", "name": args.outfit2, "type": "Clothes"},
            {"kind": "hair", "name": args.hair, "type": "Hair"},
            {"kind": "clothes", "name": f"shoes04" if args.gender == "male" else "shoes05", "type": "Shoes"},
        ]
        report["attachments"] = [r for r in (add_mhclo_dir(human, w["kind"], w["name"], w["type"]) for w in wheels) if r]

        meshes = [o for o in bpy.data.objects if o.type == "MESH"]
        body = max(meshes, key=lambda o: len(o.data.vertices)) if meshes else None
        if args.subdiv and body:
            mod = body.modifiers.new("ssSubdiv", "SUBSURF")
            mod.levels = args.subdiv
            mod.render_levels = args.subdiv
            report["subdiv"] = {"object": body.name, "levels": args.subdiv}
            print("[gen-real] subsurf", args.subdiv, "on", body.name)

        if args.subdiv_body and body:
            mod = body.modifiers.new("ssSubdivBody", "SUBSURF")
            mod.levels = args.subdiv_body
            mod.render_levels = args.subdiv_body
            report["subdivBody"] = {"object": body.name, "levels": args.subdiv_body}
            print("[gen-real] subsurf(body)", args.subdiv_body, "on", body.name)

        if args.min_tris and body:
            total_before = sum(evaluated_triangle_count(o) for o in meshes
                               if getattr(o, "visible_get", lambda: True)())
            if total_before < args.min_tris and not args.subdiv and not args.subdiv_body:
                mod = body.modifiers.new("ssSubdiv", "SUBSURF")
                mod.levels = 1
                mod.render_levels = 1
                report["subdiv"] = {"object": body.name, "levels": 1, "auto": True, "before": total_before}
                print("[gen-real] auto subsurf (tris", total_before, "<", args.min_tris, ")")

        for ob in bpy.data.objects:
            if ob.type == "MESH" or ob.type == "ARMATURE":
                ob.hide_viewport = False
                ob.hide_render = False
                ob.hide_set(False)

        report["textures"] = optimize_textures(args.tex_max, not args.tex_png, args.image_quality)
        report["blendNormalized"] = normalize_material_blend()

        out_path = os.path.abspath(args.out)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        bpy.ops.export_scene.gltf(
            filepath=out_path,
            export_format="GLB",
            export_yup=True,
            export_morph=True,
            export_skins=True,
            export_apply=True,
            export_image_format=args.image_format,
            export_image_quality=args.image_quality,
            use_selection=False,
        )

        mesh_report = []
        total = 0
        for ob in bpy.data.objects:
            if ob.type != "MESH":
                continue
            tris = evaluated_triangle_count(ob)
            if tris == 0:
                continue
            mesh_report.append({
                "name": ob.name,
                "verts": len(ob.data.vertices),
                "tris": tris,
                "materials": [m.name for m in ob.data.materials if m],
                "modifiers": [m.type for m in ob.modifiers],
            })
            total += tris
        report["meshes"] = sorted(mesh_report, key=lambda m: -m["tris"])
        report["totalTris"] = total
        report["file"] = out_path
        report["bytes"] = os.path.getsize(out_path)
        report["ok"] = True
        print(f"[gen-real] EXPORT_OK {out_path} {report['bytes']} bytes totalTris={total}")
    except Exception:
        traceback.print_exc()
        report["ok"] = False
        report["error"] = traceback.format_exc()
        print("[gen-real] FAILED")

    if args.report:
        rp = os.path.abspath(args.report)
        os.makedirs(os.path.dirname(rp), exist_ok=True)
        with open(rp, "w", encoding="utf-8") as fh:
            json.dump(report, fh, ensure_ascii=False, indent=2)
        print("[gen-real] report:", rp)
    return 0 if report.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
