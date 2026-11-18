"""S-Senna CarKit — Blender add-on (extension) to prepare, validate and export cars,
universal parts and rims for the S-Senna game.

The pure modules (``conventions``, ``naming``, ``geometry``, ``validator``,
``manifest``) don't need Blender, so they can be tested with plain Python.
"""

ADDON_VERSION = "0.1.0"

try:
    import bpy  # noqa: F401
except ImportError:  # Imported outside Blender (tests of the pure modules).
    bpy = None


def register() -> None:
    from . import ui

    ui.register()


def unregister() -> None:
    from . import ui

    ui.unregister()
