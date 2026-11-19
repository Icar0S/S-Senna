"""The buttons of the S-Senna panel. Every operator supports undo (Ctrl+Z)."""

from __future__ import annotations

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

from . import exporter, geometry, materials, naming, scene_info, validator
from .conventions import Conventions

INCH = 0.0254
GUIDE_NAME = "guia"
UNDO = {"REGISTER", "UNDO"}

_conventions: Conventions | None = None


def conv() -> Conventions:
    global _conventions
    if _conventions is None:
        _conventions = Conventions.load()
    return _conventions


def addon_version() -> str:
    from . import ADDON_VERSION

    return ADDON_VERSION


# --- Kit collections -------------------------------------------------------------


def kit_collection(context) -> bpy.types.Collection | None:
    """The kit being worked on: the one picked in the panel, else the active collection."""
    props = context.scene.senna
    if props.kit is not None:
        return props.kit
    active = context.view_layer.active_layer_collection.collection
    return active if active.get(scene_info.KIND_PROP) else None


def sub_collection(kit: bpy.types.Collection, base: str) -> bpy.types.Collection:
    """Child collection ``<base>-<slug>`` of the kit (created if missing)."""
    slug = kit.get(scene_info.SLUG_PROP, kit.name)
    name = f"{base}-{slug}"
    for child in kit.children:
        if child.name == name:
            return child
    child = bpy.data.collections.new(name)
    kit.children.link(child)
    return child


def create_kit(context, kind: str, prefix: str, slug: str) -> bpy.types.Collection:
    name = f"{prefix}-{slug}"
    kit = bpy.data.collections.get(name)
    if kit is None:
        kit = bpy.data.collections.new(name)
        context.scene.collection.children.link(kit)
    kit[scene_info.KIND_PROP] = kind
    kit[scene_info.SLUG_PROP] = slug
    context.scene.senna.kit = kit
    return kit


def move_to(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)


def dims_mm(context) -> dict:
    props = context.scene.senna
    return {
        "length": props.length_mm,
        "width": props.width_mm,
        "height": props.height_mm,
        "wheelbase": props.wheelbase_mm,
    }


def _guide(name: str, mesh: bpy.types.Mesh, collection: bpy.types.Collection) -> bpy.types.Object:
    old = bpy.data.objects.get(name)
    if old is not None:
        bpy.data.objects.remove(old, do_unlink=True)
    obj = bpy.data.objects.new(name, mesh)
    obj.display_type = "WIRE"
    obj.hide_select = True
    obj.hide_render = True
    obj[scene_info.IGNORE_PROP] = True
    collection.objects.link(obj)
    return obj


def _box_mesh(name: str, size: Vector, bottom_center: Vector) -> bpy.types.Mesh:
    mesh = bpy.data.meshes.new(name)
    data = bmesh.new()
    bmesh.ops.create_cube(data, size=1.0)
    bmesh.ops.scale(data, vec=size, verts=data.verts)
    bmesh.ops.translate(data, vec=bottom_center + Vector((0.0, 0.0, size.z / 2.0)), verts=data.verts)
    data.to_mesh(mesh)
    data.free()
    return mesh


def _cylinder_x_mesh(name: str, diameter: float, width: float, segments: int = 32) -> bpy.types.Mesh:
    mesh = bpy.data.meshes.new(name)
    data = bmesh.new()
    bmesh.ops.create_cone(
        data, cap_ends=True, segments=segments, radius1=diameter / 2.0, radius2=diameter / 2.0, depth=width
    )
    bmesh.ops.rotate(data, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90.0), 3, "Y"), verts=data.verts)
    data.to_mesh(mesh)
    data.free()
    return mesh


# --- 1. New car --------------------------------------------------------------------


class SENNA_OT_new_car(bpy.types.Operator):
    bl_idname = "senna.new_car"
    bl_label = "Novo carro"
    bl_description = "Cria a coleção do carro, a caixa-guia com as dimensões reais e os planos de referência"
    bl_options = UNDO

    def execute(self, context):
        props = context.scene.senna
        slug = props.slug.strip().lower()
        if not slug or not slug.replace("_", "").isalnum():
            self.report({"ERROR"}, "Nome (slug) inválido: use letras minúsculas, números e _")
            return {"CANCELLED"}
        kit = create_kit(context, validator.KIND_CAR, "carro", slug)
        for base in ("peças", "soquetes", "rodas"):
            sub_collection(kit, base)
        refs = sub_collection(kit, scene_info.REFERENCE_COLLECTION)
        size = Vector((props.width_mm, props.length_mm, props.height_mm)) / 1000.0
        _guide(f"{GUIDE_NAME}-{slug}", _box_mesh(f"{GUIDE_NAME}-{slug}", size, Vector((0, 0, 0))), refs)
        for key, value in dims_mm(context).items():
            kit[f"dim_{key}_mm"] = value
        self._references(props, refs, size, slug)
        self.report({"INFO"}, f"Carro '{slug}' criado: modele dentro da caixa-guia (frente para -Y)")
        return {"FINISHED"}

    def _references(self, props, refs, size: Vector, slug: str) -> None:
        views = {
            "frente": (props.ref_front, Vector((0, -size.y / 2 - 0.05, size.z / 2)), (90.0, 0.0, 0.0), size.x),
            "traseira": (props.ref_rear, Vector((0, size.y / 2 + 0.05, size.z / 2)), (90.0, 0.0, 180.0), size.x),
            "lateral": (props.ref_side, Vector((size.x / 2 + 0.05, 0, size.z / 2)), (90.0, 0.0, 90.0), size.y),
            "topo": (props.ref_top, Vector((0, 0, -0.01)), (0.0, 0.0, 0.0), size.y),
        }
        for view, (path, location, rotation, extent) in views.items():
            if not path or not os.path.isfile(bpy.path.abspath(path)):
                continue
            image = bpy.data.images.load(bpy.path.abspath(path), check_existing=True)
            name = f"ref-{view}-{slug}"
            old = bpy.data.objects.get(name)
            if old is not None:
                bpy.data.objects.remove(old, do_unlink=True)
            empty = bpy.data.objects.new(name, None)
            empty.empty_display_type = "IMAGE"
            empty.data = image
            empty.empty_display_size = extent
            empty.location = location
            empty.rotation_euler = [math.radians(angle) for angle in rotation]
            empty.use_empty_image_alpha = True
            empty.color[3] = 0.5
            empty.hide_select = True
            empty[scene_info.IGNORE_PROP] = True
            refs.objects.link(empty)


# --- 2. Modeling tools ---------------------------------------------------------------


class SENNA_OT_fit_length(bpy.types.Operator):
    bl_idname = "senna.fit_length"
    bl_label = "Ajustar escala pelo comprimento"
    bl_description = "Escala a malha ativa para ter o comprimento real (eixo Y) informado"
    bl_options = UNDO

    @classmethod
    def poll(cls, context):
        return context.active_object is not None and context.active_object.type == "MESH"

    def execute(self, context):
        obj = context.active_object
        corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        current = max(c.y for c in corners) - min(c.y for c in corners)
        target = context.scene.senna.length_mm / 1000.0
        if current <= 0.0 or target <= 0.0:
            self.report({"ERROR"}, "Comprimento inválido")
            return {"CANCELLED"}
        obj.scale = obj.scale * (target / current)
        self.report({"INFO"}, f"Escala x{target / current:.3f}; aplique com Ctrl+A > Escala")
        return {"FINISHED"}


class SENNA_OT_separate_part(bpy.types.Operator):
    bl_idname = "senna.separate_part"
    bl_label = "Separar como peça"
    bl_description = "Separa as faces selecionadas em um objeto <slot>-stock"
    bl_options = UNDO

    @classmethod
    def poll(cls, context):
        return context.active_object is not None and context.mode == "EDIT_MESH"

    def execute(self, context):
        kit = kit_collection(context)
        slot = context.scene.senna.slot
        source = context.active_object
        before = set(bpy.data.objects)
        bpy.ops.mesh.separate(type="SELECTED")
        created = [obj for obj in bpy.data.objects if obj not in before]
        bpy.ops.object.mode_set(mode="OBJECT")
        if not created:
            self.report({"ERROR"}, "Selecione as faces da peça antes")
            return {"CANCELLED"}
        part = created[0]
        names = [obj.name for obj in bpy.data.objects]
        variant = (
            naming.STOCK
            if naming.part_name(slot, naming.STOCK, conv()) not in names
            else naming.next_variant(slot, names, conv())
        )
        part.name = naming.part_name(slot, variant, conv())
        if kit is not None:
            move_to(part, sub_collection(kit, "peças"))
        bpy.ops.object.select_all(action="DESELECT")
        part.select_set(True)
        context.view_layer.objects.active = part
        self.report({"INFO"}, f"Peça '{part.name}' separada de '{source.name}'")
        return {"FINISHED"}


class SENNA_OT_create_variant(bpy.types.Operator):
    bl_idname = "senna.create_variant"
    bl_label = "Criar variante"
    bl_description = "Duplica a peça ativa como <slot>-kitNN e esconde a original"
    bl_options = UNDO

    @classmethod
    def poll(cls, context):
        obj = context.active_object
        return obj is not None and obj.type == "MESH" and naming.classify(obj.name, conv()).role == naming.ROLE_PART

    def execute(self, context):
        source = context.active_object
        slot = naming.classify(source.name, conv()).slot
        copy = source.copy()
        copy.data = source.data.copy()
        copy.name = naming.part_name(
            slot, naming.next_variant(slot, [o.name for o in bpy.data.objects], conv()), conv()
        )
        for collection in source.users_collection:
            collection.objects.link(copy)
        source.hide_set(True)
        bpy.ops.object.select_all(action="DESELECT")
        copy.select_set(True)
        context.view_layer.objects.active = copy
        self.report({"INFO"}, f"Variante '{copy.name}' criada")
        return {"FINISHED"}


class SENNA_OT_assign_material(bpy.types.Operator):
    bl_idname = "senna.assign_material"
    bl_label = "Material do jogo"
    bl_description = "Atribui o material oficial escolhido às faces selecionadas (ou ao objeto inteiro)"
    bl_options = UNDO

    @classmethod
    def poll(cls, context):
        return context.active_object is not None and context.active_object.type == "MESH"

    def execute(self, context):
        name = context.scene.senna.material
        material = materials.ensure_material(name, conv())
        changed = materials.assign(context.active_object, material, context.mode == "EDIT_MESH")
        self.report({"INFO"}, f"'{name}' em {changed} face(s)")
        return {"FINISHED"}


class SENNA_OT_create_socket(bpy.types.Operator):
    bl_idname = "senna.create_socket"
    bl_label = "Criar soquete"
    bl_description = "Cria (ou move) o soquete escolhido na posição do cursor 3D"
    bl_options = UNDO

    def execute(self, context):
        props = context.scene.senna
        name = naming.socket_name(props.socket, conv())
        empty = bpy.data.objects.get(name)
        if empty is None:
            empty = bpy.data.objects.new(name, None)
            empty.empty_display_type = "PLAIN_AXES"
            empty.empty_display_size = 0.15
            kit = kit_collection(context)
            (sub_collection(kit, "soquetes") if kit else context.scene.collection).objects.link(empty)
        empty.location = context.scene.cursor.location
        for key, value in (("width_m", props.socket_width_m), ("length_m", props.socket_length_m)):
            if value > 0.0:
                empty[key] = value
            elif key in empty:
                del empty[key]
        self.report({"INFO"}, f"Soquete '{name}' em {tuple(round(v, 3) for v in empty.location)}")
        return {"FINISHED"}


class SENNA_OT_mirror_left_right(bpy.types.Operator):
    bl_idname = "senna.mirror_left_right"
    bl_label = "Espelhar L→R"
    bl_description = "Cria ou atualiza o par direito (_R) de cada soquete/peça _L do kit"
    bl_options = UNDO

    def execute(self, context):
        kit = kit_collection(context)
        if kit is None:
            self.report({"ERROR"}, "Escolha o kit (coleção do carro) no painel")
            return {"CANCELLED"}
        count = 0
        for obj in scene_info.kit_objects(kit):
            target_name = naming.mirror_name(obj.name)
            if not obj.name.endswith("_L") or target_name is None:
                continue
            target = bpy.data.objects.get(target_name)
            if target is None:
                target = obj.copy()
                target.name = target_name
                for collection in obj.users_collection:
                    collection.objects.link(target)
            if obj.type == "MESH":
                target.data = obj.data.copy()
                target.data.transform(Matrix.Scale(-1.0, 4, (1.0, 0.0, 0.0)))
                target.data.flip_normals()
            target.location = (-obj.location.x, obj.location.y, obj.location.z)
            target.rotation_euler = (obj.rotation_euler.x, -obj.rotation_euler.y, -obj.rotation_euler.z)
            for key in obj.keys():
                target[key] = obj[key]
            count += 1
        self.report({"INFO"}, f"{count} par(es) espelhado(s)")
        return {"FINISHED"}


class SENNA_OT_detect_wheels(bpy.types.Operator):
    bl_idname = "senna.detect_wheels"
    bl_label = "Detectar rodas"
    bl_description = (
        "Com as 4 rodas selecionadas: cria wheel-FL/FR/RL/RR no centro de cada uma (e o rim-stock, se escolhido)"
    )
    bl_options = UNDO

    def execute(self, context):
        props = context.scene.senna
        rim_source = props.rim_source
        meshes = [obj for obj in context.selected_objects if obj.type == "MESH" and obj != rim_source]
        boxes = []
        for obj in meshes:
            corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
            boxes.append(
                (
                    obj.name,
                    tuple(min(c[i] for c in corners) for i in range(3)),
                    tuple(max(c[i] for c in corners) for i in range(3)),
                )
            )
        try:
            wheels = geometry.detect_wheels(boxes)
        except ValueError as error:
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}
        if props.symmetric_wheels:
            wheels = geometry.symmetrize(wheels)
        kit = kit_collection(context)
        target = sub_collection(kit, "rodas") if kit else context.scene.collection
        refs = sub_collection(kit, scene_info.REFERENCE_COLLECTION) if kit else None
        for position, data in wheels.items():
            name = naming.wheel_name(position, conv())
            empty = bpy.data.objects.get(name)
            if empty is None:
                empty = bpy.data.objects.new(name, None)
                empty.empty_display_type = "SPHERE"
                target.objects.link(empty)
            empty.empty_display_size = data["radius"]
            empty.location = data["center"]
            empty[validator.RADIUS_PROP] = round(data["radius"], 4)
        for obj in meshes:
            obj.hide_set(True)
            if refs is not None:
                move_to(obj, refs)
        if rim_source is not None:
            self._make_rim(rim_source, wheels["FL"]["center"], target, refs)
        self.report({"INFO"}, f"Rodas detectadas (raio {wheels['FL']['radius']:.3f} m)")
        return {"FINISHED"}

    def _make_rim(self, source, center, target, refs) -> None:
        name = naming.rim_name(conv())
        old = bpy.data.objects.get(name)
        if old is not None:
            bpy.data.objects.remove(old, do_unlink=True)
        mesh = source.data.copy()
        mesh.transform(source.matrix_world)
        corners = [Vector(v.co) for v in mesh.vertices]
        minimum = Vector([min(c[i] for c in corners) for i in range(3)])
        maximum = Vector([max(c[i] for c in corners) for i in range(3)])
        size = maximum - minimum
        diameter_in, width_in = conv().rim_model()
        mesh.transform(Matrix.Translation(-(minimum + maximum) / 2.0))
        scale = (
            width_in * INCH / max(size.x, 1e-6),
            diameter_in * INCH / max(size.y, 1e-6),
            diameter_in * INCH / max(size.z, 1e-6),
        )
        mesh.transform(Matrix.Diagonal((*scale, 1.0)))
        rim = bpy.data.objects.new(name, mesh)
        rim.location = center
        target.objects.link(rim)
        source.hide_set(True)
        if refs is not None:
            move_to(source, refs)


class SENNA_OT_preview_rim(bpy.types.Operator):
    bl_idname = "senna.preview_rim"
    bl_label = "Pré-visualizar aro máximo"
    bl_description = "Mostra/esconde um cilindro fantasma do pneu com o aro e a tala máximos em cada roda"
    bl_options = UNDO

    def execute(self, context):
        props = context.scene.senna
        existing = [obj for obj in bpy.data.objects if obj.name.startswith("preview_rim_")]
        if existing:
            for obj in existing:
                bpy.data.objects.remove(obj, do_unlink=True)
            return {"FINISHED"}
        kit = kit_collection(context)
        refs = sub_collection(kit, scene_info.REFERENCE_COLLECTION) if kit else context.scene.collection
        for position in conv().wheels():
            anchor = bpy.data.objects.get(naming.wheel_name(position, conv()))
            if anchor is None:
                continue
            diameter = float(anchor.get(validator.RADIUS_PROP, 0.31)) * 2.0
            width = props.preview_width_in * INCH + 0.02
            ghost = _guide(
                f"preview_rim_{position}", _cylinder_x_mesh(f"preview_rim_{position}", diameter, width), refs
            )
            ghost.location = anchor.location
            ghost.show_in_front = True
        return {"FINISHED"}


# --- 3. Validate / 4. Export ---------------------------------------------------------------


def run_validation(context) -> list[validator.Issue]:
    kit = kit_collection(context)
    props = context.scene.senna
    props.issues.clear()
    if kit is None:
        return []
    issues = validator.validate(scene_info.collect(kit, dims_mm(context)), conv())
    for issue in issues:
        item = props.issues.add()
        item.severity = issue.severity
        item.message = issue.message
        item.object_name = issue.object_name
    errors = sum(1 for issue in issues if issue.severity == validator.ERROR)
    props.validation_summary = f"{errors} erro(s), {len(issues) - errors} aviso(s)"
    return issues


class SENNA_OT_validate(bpy.types.Operator):
    bl_idname = "senna.validate"
    bl_label = "Validar"
    bl_description = "Confere nomes, escala, eixos, materiais, rodas, dimensões e orçamento de triângulos"

    def execute(self, context):
        if kit_collection(context) is None:
            self.report({"ERROR"}, "Escolha o kit (coleção do carro, peça ou aro) no painel")
            return {"CANCELLED"}
        issues = run_validation(context)
        # WARNING, not ERROR: validating worked (and ERROR aborts scripts that call the operator).
        level = {"WARNING"} if validator.has_errors(issues) else {"INFO"}
        self.report(level, context.scene.senna.validation_summary)
        return {"FINISHED"}


class SENNA_OT_select_issue(bpy.types.Operator):
    bl_idname = "senna.select_issue"
    bl_label = "Selecionar"
    bl_description = "Seleciona o objeto do problema"

    object_name: bpy.props.StringProperty()

    def execute(self, context):
        obj = bpy.data.objects.get(self.object_name)
        if obj is None:
            return {"CANCELLED"}
        if context.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.select_all(action="DESELECT")
        obj.hide_set(False)
        obj.select_set(True)
        context.view_layer.objects.active = obj
        return {"FINISHED"}


class SENNA_OT_export(bpy.types.Operator):
    bl_idname = "senna.export"
    bl_label = "Exportar para o S-Senna"
    bl_description = "Valida e exporta o .glb e o carkit_manifest.json para a pasta escolhida (trabalha numa cópia)"

    def execute(self, context):
        kit = kit_collection(context)
        props = context.scene.senna
        if kit is None:
            self.report({"ERROR"}, "Escolha o kit no painel")
            return {"CANCELLED"}
        out_dir = bpy.path.abspath(props.export_dir)
        if not out_dir:
            self.report({"ERROR"}, "Escolha a pasta de exportação")
            return {"CANCELLED"}
        if context.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        run_validation(context)
        try:
            glb_path, data = exporter.export_kit(kit, out_dir, conv(), addon_version(), dims_mm(context))
        except exporter.ExportError as error:
            self.report({"ERROR"}, str(error))
            return {"CANCELLED"}
        self.report({"INFO"}, f"Exportado: {glb_path} ({data['triangles']['total']} triângulos)")
        return {"FINISHED"}


# --- 5. Universal parts and rims -------------------------------------------------------------


class SENNA_OT_new_universal_part(bpy.types.Operator):
    bl_idname = "senna.new_universal_part"
    bl_label = "Nova peça universal"
    bl_description = "Cria a coleção da peça com a origem no ponto de fixação e a largura de referência"
    bl_options = UNDO

    def execute(self, context):
        props = context.scene.senna
        slug = props.part_slug.strip().lower()
        kit = create_kit(context, validator.KIND_PART, "peça", slug)
        kit["slot"] = props.part_slot
        kit["reference_width_m"] = props.reference_width_m
        refs = sub_collection(kit, scene_info.REFERENCE_COLLECTION)
        size = Vector((props.reference_width_m, 0.3, 0.02))
        _guide(f"{GUIDE_NAME}-{slug}", _box_mesh(f"{GUIDE_NAME}-{slug}", size, Vector((0, 0, 0))), refs)
        self.report(
            {"INFO"},
            f"Modele a peça '{naming.part_name(props.part_slot, slug, conv())}' com a origem no ponto de fixação",
        )
        return {"FINISHED"}


class SENNA_OT_new_rim(bpy.types.Operator):
    bl_idname = "senna.new_rim"
    bl_label = "Novo aro"
    bl_description = 'Cria a coleção do aro com o cilindro-guia de 18" x 8" (eixo X, face externa para +X)'
    bl_options = UNDO

    def execute(self, context):
        props = context.scene.senna
        slug = props.rim_slug.strip().lower()
        kit = create_kit(context, validator.KIND_RIM, "aro", slug)
        refs = sub_collection(kit, scene_info.REFERENCE_COLLECTION)
        diameter_in, width_in = conv().rim_model()
        _guide(
            f"{GUIDE_NAME}-{slug}", _cylinder_x_mesh(f"{GUIDE_NAME}-{slug}", diameter_in * INCH, width_in * INCH), refs
        )
        self.report({"INFO"}, f"Modele o aro 'rim-{slug}' dentro do cilindro-guia")
        return {"FINISHED"}


CLASSES = (
    SENNA_OT_new_car,
    SENNA_OT_fit_length,
    SENNA_OT_separate_part,
    SENNA_OT_create_variant,
    SENNA_OT_assign_material,
    SENNA_OT_create_socket,
    SENNA_OT_mirror_left_right,
    SENNA_OT_detect_wheels,
    SENNA_OT_preview_rim,
    SENNA_OT_validate,
    SENNA_OT_select_issue,
    SENNA_OT_export,
    SENNA_OT_new_universal_part,
    SENNA_OT_new_rim,
)
