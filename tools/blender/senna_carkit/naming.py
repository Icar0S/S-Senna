"""Object names of the convention (doc 03 §4.3): ``<slot>-<variant>``, ``socket-<name>``,
``wheel-<pos>``, ``rim-stock``, ``collision-<n>``, ``glass-stock``...

Pure Python (no ``bpy``).
"""

from __future__ import annotations

import re
from dataclasses import dataclass

from .conventions import Conventions

ROLE_PART = "part"
ROLE_SOCKET = "socket"
ROLE_WHEEL = "wheel"
ROLE_RIM = "rim"
ROLE_COLLISION = "collision"
ROLE_FIXED = "fixed"
STOCK = "stock"
VARIANT_PREFIX = "kit"

_DUPLICATE = re.compile(r"\.\d{3}$")
_VARIANT = re.compile(r"^[a-z0-9_]+$")


@dataclass
class Classification:
    role: str | None = None
    slot: str = ""
    variant: str = ""
    problem: str = ""


def classify(name: str, conv: Conventions) -> Classification:
    """Role of an object from its name. ``role`` is None (with ``problem``) when unknown."""
    sep = conv.separator()
    if sep not in name or name.startswith(sep) or name.endswith(sep):
        return Classification(problem=f"nome fora do padrão <tipo>{sep}<nome>: '{name}'")
    prefix, suffix = name.split(sep, 1)
    if prefix in conv.all_slots():
        if not _VARIANT.match(suffix):
            return Classification(problem=f"variante inválida em '{name}' (use a-z, 0-9 e _)")
        return Classification(ROLE_PART, prefix, suffix)
    if prefix == conv.node_prefix(ROLE_SOCKET):
        if suffix not in conv.sockets():
            return Classification(problem=f"soquete desconhecido '{suffix}'")
        return Classification(ROLE_SOCKET, suffix)
    if prefix == conv.node_prefix(ROLE_WHEEL):
        if suffix not in conv.wheels():
            return Classification(problem=f"posição de roda desconhecida '{suffix}'")
        return Classification(ROLE_WHEEL, suffix)
    if prefix == conv.node_prefix(ROLE_RIM):
        return Classification(ROLE_RIM, "", suffix)
    if prefix == conv.node_prefix(ROLE_COLLISION):
        return Classification(ROLE_COLLISION, "", suffix)
    if prefix in conv.fixed_prefixes():
        return Classification(ROLE_FIXED, prefix, suffix)
    return Classification(problem=f"prefixo desconhecido '{prefix}' em '{name}'")


def has_duplicate_suffix(name: str) -> bool:
    """True for Blender's automatic copies (``body-stock.001``)."""
    return bool(_DUPLICATE.search(name))


def has_forbidden_suffix(name: str, conv: Conventions) -> bool:
    lower = name.lower()
    return any(lower.endswith(suffix) for suffix in conv.forbidden_suffixes())


def part_name(slot: str, variant: str, conv: Conventions) -> str:
    return f"{slot}{conv.separator()}{variant}"


def socket_name(socket: str, conv: Conventions) -> str:
    return f"{conv.node_prefix(ROLE_SOCKET)}{conv.separator()}{socket}"


def wheel_name(position: str, conv: Conventions) -> str:
    return f"{conv.node_prefix(ROLE_WHEEL)}{conv.separator()}{position}"


def rim_name(conv: Conventions, variant: str = STOCK) -> str:
    return f"{conv.node_prefix(ROLE_RIM)}{conv.separator()}{variant}"


def next_variant(slot: str, existing_names: list[str], conv: Conventions) -> str:
    """Next free ``kitNN`` variant of ``slot`` (``kit01``, ``kit02``...)."""
    taken = set()
    for name in existing_names:
        info = classify(name, conv)
        if info.role == ROLE_PART and info.slot == slot:
            taken.add(info.variant)
    number = 1
    while f"{VARIANT_PREFIX}{number:02d}" in taken:
        number += 1
    return f"{VARIANT_PREFIX}{number:02d}"


def mirror_name(name: str) -> str | None:
    """``socket-exhaust_L`` -> ``socket-exhaust_R`` (and back); None if not a side pair."""
    if name.endswith("_L"):
        return name[:-2] + "_R"
    if name.endswith("_R"):
        return name[:-2] + "_L"
    return None
