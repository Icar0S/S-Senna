"""Panel "S-Senna" in the 3D Viewport sidebar (N), scene properties and preferences."""

from __future__ import annotations

import bpy

from . import operators
from .conventions import Conventions


def _items(values: list[str]) -> list[tuple[str, str, str]]:
    return [(value, value, "") for value in values]


_CONV = Conventions.load()
SLOT_ITEMS = _items(_CONV.all_slots())
MATERIAL_ITEMS = _items(_CONV.materials())
SOCKET_ITEMS = _items(_CONV.sockets())


class SennaPreferences(bpy.types.AddonPreferences):
    bl_idname = __package__

    default_export_dir: bpy.props.StringProperty(
        name="Pasta padrão de exportação",
        description="Ex.: <repositório>/godot/content/packs/base/cars",
        subtype="DIR_PATH",
    )

    def draw(self, context):
        self.layout.prop(self, "default_export_dir")


class SennaIssue(bpy.types.PropertyGroup):
    severity: bpy.props.StringProperty()
    message: bpy.props.StringProperty()
    object_name: bpy.props.StringProperty()


class SennaSceneProps(bpy.types.PropertyGroup):
    kit: bpy.props.PointerProperty(name="Kit", type=bpy.types.Collection, description="Coleção do carro, peça ou aro")
    slug: bpy.props.StringProperty(
        name="Nome (slug)", default="meu_carro", description="Letras minúsculas, números e _"
    )
    length_mm: bpy.props.IntProperty(name="Comprimento (mm)", default=4300, min=1000, max=10000)
    width_mm: bpy.props.IntProperty(name="Largura (mm)", default=1760, min=500, max=4000)
    height_mm: bpy.props.IntProperty(name="Altura (mm)", default=1250, min=500, max=4000)
    wheelbase_mm: bpy.props.IntProperty(name="Entre-eixos (mm)", default=2550, min=500, max=8000)
    ref_front: bpy.props.StringProperty(name="Frente", subtype="FILE_PATH")
    ref_side: bpy.props.StringProperty(name="Lateral", subtype="FILE_PATH")
    ref_rear: bpy.props.StringProperty(name="Traseira", subtype="FILE_PATH")
    ref_top: bpy.props.StringProperty(name="Topo", subtype="FILE_PATH")
    slot: bpy.props.EnumProperty(name="Slot", items=SLOT_ITEMS)
    material: bpy.props.EnumProperty(name="Material", items=MATERIAL_ITEMS)
    socket: bpy.props.EnumProperty(name="Soquete", items=SOCKET_ITEMS)
    socket_width_m: bpy.props.FloatProperty(name="Largura (m)", default=0.0, min=0.0, max=5.0)
    socket_length_m: bpy.props.FloatProperty(name="Comprimento (m)", default=0.0, min=0.0, max=10.0)
    symmetric_wheels: bpy.props.BoolProperty(name="Simetrizar", default=True)
    rim_source: bpy.props.PointerProperty(
        name="Aro original", type=bpy.types.Object, description="Malha do aro a normalizar como rim-stock (opcional)"
    )
    preview_width_in: bpy.props.FloatProperty(name="Tala máx. (pol)", default=10.0, min=4.0, max=15.0)
    export_dir: bpy.props.StringProperty(name="Pasta", subtype="DIR_PATH")
    part_slot: bpy.props.EnumProperty(name="Slot", items=SLOT_ITEMS)
    part_slug: bpy.props.StringProperty(name="Nome", default="minha_peca")
    reference_width_m: bpy.props.FloatProperty(name="Largura de referência (m)", default=1.4, min=0.1, max=5.0)
    rim_slug: bpy.props.StringProperty(name="Nome", default="meu_aro")
    issues: bpy.props.CollectionProperty(type=SennaIssue)
    issue_index: bpy.props.IntProperty()
    validation_summary: bpy.props.StringProperty()


class SENNA_UL_issues(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        row = layout.row(align=True)
        row.label(text=item.message, icon="ERROR" if item.severity == "error" else "INFO")
        if item.object_name:
            operator = row.operator("senna.select_issue", text="", icon="RESTRICT_SELECT_OFF")
            operator.object_name = item.object_name


class _Panel:
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "S-Senna"


class SENNA_PT_main(_Panel, bpy.types.Panel):
    bl_label = "S-Senna CarKit"

    def draw(self, context):
        props = context.scene.senna
        self.layout.prop(props, "kit")


class SENNA_PT_new_car(_Panel, bpy.types.Panel):
    bl_label = "1. Novo carro"
    bl_parent_id = "SENNA_PT_main"

    def draw(self, context):
        props = context.scene.senna
        col = self.layout.column(align=True)
        for name in ("slug", "length_mm", "width_mm", "height_mm", "wheelbase_mm"):
            col.prop(props, name)
        box = self.layout.box()
        box.label(text="Imagens de referência (opcional)")
        for name in ("ref_front", "ref_side", "ref_rear", "ref_top"):
            box.prop(props, name)
        self.layout.operator("senna.new_car", icon="AUTO")


class SENNA_PT_tools(_Panel, bpy.types.Panel):
    bl_label = "2. Ferramentas"
    bl_parent_id = "SENNA_PT_main"

    def draw(self, context):
        props = context.scene.senna
        layout = self.layout
        layout.operator("senna.fit_length", icon="FULLSCREEN_ENTER")
        row = layout.row(align=True)
        row.prop(props, "slot", text="")
        row.operator("senna.separate_part")
        layout.operator("senna.create_variant", icon="DUPLICATE")
        row = layout.row(align=True)
        row.prop(props, "material", text="")
        row.operator("senna.assign_material")
        box = layout.box()
        box.prop(props, "socket")
        row = box.row(align=True)
        row.prop(props, "socket_width_m")
        row.prop(props, "socket_length_m")
        box.operator("senna.create_socket", icon="EMPTY_AXIS")
        layout.operator("senna.mirror_left_right", icon="MOD_MIRROR")
        box = layout.box()
        box.prop(props, "rim_source")
        box.prop(props, "symmetric_wheels")
        box.operator("senna.detect_wheels", icon="MESH_CYLINDER")
        row = box.row(align=True)
        row.prop(props, "preview_width_in")
        row.operator("senna.preview_rim", text="Aro máx.")


class SENNA_PT_validate(_Panel, bpy.types.Panel):
    bl_label = "3. Validar"
    bl_parent_id = "SENNA_PT_main"

    def draw(self, context):
        props = context.scene.senna
        self.layout.operator("senna.validate", icon="CHECKMARK")
        if props.validation_summary:
            self.layout.label(text=props.validation_summary)
        self.layout.template_list("SENNA_UL_issues", "", props, "issues", props, "issue_index", rows=6)


class SENNA_PT_export(_Panel, bpy.types.Panel):
    bl_label = "4. Exportar"
    bl_parent_id = "SENNA_PT_main"

    def draw(self, context):
        props = context.scene.senna
        self.layout.prop(props, "export_dir")
        self.layout.operator("senna.export", icon="EXPORT")


class SENNA_PT_library(_Panel, bpy.types.Panel):
    bl_label = "5. Peças universais e aros"
    bl_parent_id = "SENNA_PT_main"
    bl_options = {"DEFAULT_CLOSED"}

    def draw(self, context):
        props = context.scene.senna
        box = self.layout.box()
        box.prop(props, "part_slot")
        box.prop(props, "part_slug")
        box.prop(props, "reference_width_m")
        box.operator("senna.new_universal_part")
        box = self.layout.box()
        box.prop(props, "rim_slug")
        box.operator("senna.new_rim")


CLASSES = (
    SennaPreferences,
    SennaIssue,
    SennaSceneProps,
    SENNA_UL_issues,
    SENNA_PT_main,
    SENNA_PT_new_car,
    SENNA_PT_tools,
    SENNA_PT_validate,
    SENNA_PT_export,
    SENNA_PT_library,
)


def register() -> None:
    for cls in CLASSES:
        bpy.utils.register_class(cls)
    for cls in operators.CLASSES:
        bpy.utils.register_class(cls)
    bpy.types.Scene.senna = bpy.props.PointerProperty(type=SennaSceneProps)


def unregister() -> None:
    del bpy.types.Scene.senna
    for cls in reversed(operators.CLASSES):
        bpy.utils.unregister_class(cls)
    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)
