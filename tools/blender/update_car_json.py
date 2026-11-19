#!/usr/bin/env python3
"""Updates a ``car.json`` from the ``carkit_manifest.json`` exported by the Blender add-on.

Writes what comes from the model — dimensions, parts, sockets, wheel anchors, tire
diameter and stock rim — and keeps everything else (name, stats, prices, part names,
``tuning_overrides``...). Precursor of the Studio's "import car" (Etapa 06).

Usage: python tools/blender/update_car_json.py <carkit_manifest.json> <car.json>
"""

from __future__ import annotations

import json
import sys

WHEELBASE_KEYS = ("FL", "RL")


def update(car: dict, manifest: dict) -> dict:
    """Returns ``car`` updated with the manifest (the input dict is changed too)."""
    dims = dict(car.get("dimensions_mm", {}))
    # What the model really measures (the validator already checked it against the typed
    # dimensions, ±2%); the typed ones are the fallback.
    measured = manifest.get("measured_mm") or manifest.get("dimensions_mm") or {}
    for key in ("length", "width", "height"):
        if key in measured:
            dims[key] = int(measured[key])
    wheels = manifest.get("wheels", {})
    if all(key in wheels for key in WHEELBASE_KEYS):
        dims["wheelbase"] = int(round((wheels["FL"]["position"][2] - wheels["RL"]["position"][2]) * 1000.0))
    car["dimensions_mm"] = dims

    # Parts and sockets keep the order they had in car.json; new ones go to the end.
    exported = {(part["slot"], part["variant"]) for part in manifest.get("parts", [])}
    parts = [dict(entry) for entry in car.get("parts", []) if (entry["slot"], entry["variant"]) in exported]
    known = {(entry["slot"], entry["variant"]) for entry in parts}
    for part in manifest.get("parts", []):
        if (part["slot"], part["variant"]) not in known:
            parts.append({"slot": part["slot"], "variant": part["variant"]})
    car["parts"] = parts

    old_sockets = car.get("sockets", {})
    new_sockets = manifest.get("sockets", {})
    names = [name for name in old_sockets if name in new_sockets] + [n for n in new_sockets if n not in old_sockets]
    sockets = {}
    for name in names:
        params = {key: value for key, value in new_sockets[name].items() if key != "position"}
        sockets[name] = params if params else dict(old_sockets.get(name, {}))
    car["sockets"] = sockets

    car_wheels = dict(car.get("wheels", {}))
    if wheels:
        car_wheels["anchors"] = {
            key: [round(v, 3) + 0.0 for v in value["position"]] for key, value in sorted(wheels.items())
        }
        radii = [value["radius_m"] for value in wheels.values() if value.get("radius_m")]
        if radii:
            car_wheels["tire_outer_diameter_m"] = round(2.0 * sum(radii) / len(radii), 3)
    stock = dict(car_wheels.get("stock", {}))
    if manifest.get("rim"):
        stock["rim"] = manifest["rim"]
    car_wheels["stock"] = stock
    car["wheels"] = car_wheels
    return car


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    with open(argv[1], encoding="utf-8") as handle:
        manifest = json.load(handle)
    with open(argv[2], encoding="utf-8") as handle:
        car = json.load(handle)
    update(car, manifest)
    with open(argv[2], "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(car, ensure_ascii=False, indent=2) + "\n")
    print(f"{argv[2]} atualizado a partir de {argv[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
