"""Shared conventions (slots, sockets, materials, node names, budgets).

Read from ``conventions.json`` — the same file the Godot project uses
(``godot/core/content/conventions.json``). When the add-on runs from the
repository it reads the project's file directly; the installable ``.zip``
carries a copy made by ``tools/blender/build_extension.sh``.

Pure Python (no ``bpy``): usable by the tests outside Blender.
"""

from __future__ import annotations

import json
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
BUNDLED_PATH = os.path.join(_HERE, "conventions.json")
REPO_PATH = os.path.normpath(os.path.join(_HERE, "..", "..", "..", "godot", "core", "content", "conventions.json"))


def find_path() -> str:
    """The conventions file to use: the project's when developing, else the bundled copy."""
    for candidate in (REPO_PATH, BUNDLED_PATH):
        if os.path.isfile(candidate):
            return candidate
    raise FileNotFoundError("conventions.json não encontrado (rode tools/blender/build_extension.sh)")


class Conventions:
    """Typed access to ``conventions.json``."""

    def __init__(self, data: dict, source: str = ""):
        self.data = data
        self.source = source  # file it was read from ("" when built from a dict)

    @classmethod
    def load(cls, path: str | None = None) -> Conventions:
        source = path or find_path()
        with open(source, encoding="utf-8") as handle:
            return cls(json.load(handle), source)

    # Slots, sockets, wheels -------------------------------------------------------
    def replace_slots(self) -> list[str]:
        return list(self.data["slots"]["replace"])

    def attach_slots(self) -> list[str]:
        return list(self.data["slots"]["attach"])

    def all_slots(self) -> list[str]:
        return self.replace_slots() + self.attach_slots()

    def sockets(self) -> list[str]:
        return list(self.data["sockets"])

    def recommended_sockets(self) -> list[str]:
        return list(self.data.get("recommended_sockets", []))

    def wheels(self) -> list[str]:
        return list(self.data["wheels"])

    # Materials --------------------------------------------------------------------
    def materials(self) -> list[str]:
        return list(self.data["materials"])

    def keep_prefix(self) -> str:
        return self.data.get("material_prefix_keep", "tex_")

    def is_material_name(self, name: str) -> bool:
        return name in self.data["materials"] or name.startswith(self.keep_prefix())

    def preview_color(self, name: str) -> tuple[float, float, float, float]:
        """RGBA (0..1, linear-ish) preview color of an official material."""
        hex_color = self.data.get("material_preview", {}).get(name, "#C0C0C0").lstrip("#")
        rgb = [int(hex_color[i : i + 2], 16) / 255.0 for i in (0, 2, 4)]
        return (rgb[0], rgb[1], rgb[2], 1.0)

    # Names ------------------------------------------------------------------------
    def separator(self) -> str:
        return self.data.get("name_separator", "-")

    def node_prefix(self, role: str) -> str:
        return self.data["node_prefixes"][role]

    def fixed_prefixes(self) -> list[str]:
        return list(self.data.get("fixed_prefixes", []))

    def metadata_key(self, field: str) -> str:
        return self.data["metadata_keys"][field]

    def roles(self) -> list[str]:
        return list(self.data["metadata_roles"])

    def forbidden_suffixes(self) -> list[str]:
        return list(self.data["forbidden_name_suffixes"])

    def part_finishes(self) -> list[str]:
        return list(self.data["part_finishes"])

    # Limits -----------------------------------------------------------------------
    def budget(self, name: str) -> int:
        return int(self.data["budgets"][name])

    def rim_model(self) -> tuple[float, float]:
        """(diameter, width) in inches of the reference rim (18" x 8")."""
        rim = self.data.get("rim_model", {})
        return float(rim.get("diameter_in", 18.0)), float(rim.get("width_in", 8.0))

    def tolerance(self, name: str) -> float:
        return float(self.data.get("validation", {})[name])
