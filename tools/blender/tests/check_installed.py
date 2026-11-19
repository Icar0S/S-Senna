"""Checks the add-on installed from the .zip (run by tools/blender/test_install.sh).

Run inside Blender after ``--command extension install-file --enable``: the operators
must be registered and the conventions must come from the copy INSIDE the package
(the repository is not next to an installed extension).
"""

from __future__ import annotations

import sys

import addon_utils
import bpy

module = next((m for m in addon_utils.modules() if m.__name__.endswith("senna_carkit")), None)
problems = []
if module is None:
    problems.append("add-on senna_carkit não encontrado")
else:
    if not addon_utils.check(module.__name__)[1]:
        addon_utils.enable(module.__name__, default_set=True)
    from importlib import import_module

    conventions = import_module(module.__name__ + ".conventions")
    loaded = conventions.Conventions.load()
    if "senna_carkit" not in loaded.source.replace("\\", "/"):
        problems.append(f"convenções lidas de fora do pacote: {loaded.source}")
    if not hasattr(bpy.ops.senna, "export"):
        problems.append("operador senna.export não registrado")
    if not hasattr(bpy.types.Scene, "senna"):
        problems.append("propriedades da cena não registradas")
print("check_installed:", "OK" if not problems else "; ".join(problems))
sys.exit(1 if problems else 0)
