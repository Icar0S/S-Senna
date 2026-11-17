#!/usr/bin/env python3
"""Valida os arquivos JSON do projeto.

1. Todo .json é JSON válido (UTF-8, sem BOM, sem chaves duplicadas).
2. Os schemas de schemas/ são JSON Schemas válidos (check-jsonschema --check-metaschema).
3. Cada .json de godot/ é validado contra schemas/<valor do campo "schema">.schema.json
   com o check-jsonschema (doc 03 §1: todo arquivo tem "schema" e "schema_version").

Uso: python tools/ci/validate_content.py [raiz_do_repositorio]
Requer: pip install -r tools/ci/requirements.txt
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

# Pastas (relativas à raiz) onde procurar arquivos .json.
SEARCH_DIRS = ("godot", "schemas")
SCHEMAS_DIR = "schemas"
# Nomes de pastas ignoradas em qualquer nível.
EXCLUDED_DIR_NAMES = {".godot", "addons", "reports"}


def find_json_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for search_dir in SEARCH_DIRS:
        base = root / search_dir
        if not base.is_dir():
            continue
        for path in base.rglob("*.json"):
            relative_parts = path.relative_to(root).parts[:-1]
            if EXCLUDED_DIR_NAMES.intersection(relative_parts):
                continue
            files.append(path)
    return sorted(files)


def _reject_duplicate_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"chave duplicada: {key!r}")
        result[key] = value
    return result


def load_json(path: Path) -> tuple[object | None, str | None]:
    """Retorna (dados, None) ou (None, mensagem de erro)."""
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        return None, "arquivo com BOM (salve como UTF-8 sem BOM)"
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        return None, f"não é UTF-8 válido: {error}"
    try:
        return json.loads(text, object_pairs_hook=_reject_duplicate_keys), None
    except json.JSONDecodeError as error:
        return None, f"JSON inválido: {error.msg} (linha {error.lineno}, coluna {error.colno})"
    except ValueError as error:
        return None, str(error)


def run_check_jsonschema(args: list[str]) -> int:
    command = [sys.executable, "-m", "check_jsonschema", *args]
    try:
        return subprocess.run(command, check=False).returncode
    except FileNotFoundError:
        return 127


def has_check_jsonschema() -> bool:
    result = subprocess.run(
        [sys.executable, "-c", "import check_jsonschema"], check=False, capture_output=True
    )
    return result.returncode == 0


def main(argv: list[str]) -> int:
    # Our lines and check-jsonschema's (a subprocess) must come out in order.
    sys.stdout.reconfigure(line_buffering=True)
    root =Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[2]
    files = find_json_files(root)
    errors = 0

    # 1. Sintaxe.
    groups: dict[Path, list[Path]] = {}
    for path in files:
        relative = path.relative_to(root).as_posix()
        data, message = load_json(path)
        if message is not None:
            errors += 1
            print(f"ERRO: {relative}: {message}", file=sys.stderr)
            continue
        if relative.startswith(SCHEMAS_DIR + "/"):
            continue
        schema_name = data.get("schema") if isinstance(data, dict) else None
        if not isinstance(schema_name, str) or not schema_name:
            errors += 1
            print(f"ERRO: {relative}: falta o campo \"schema\" (doc 03 §1)", file=sys.stderr)
            continue
        schema_file = root / SCHEMAS_DIR / f"{schema_name}.schema.json"
        if not schema_file.is_file():
            errors += 1
            print(
                f"ERRO: {relative}: schema desconhecido \"{schema_name}\" "
                f"(não existe {SCHEMAS_DIR}/{schema_name}.schema.json)",
                file=sys.stderr,
            )
            continue
        groups.setdefault(schema_file, []).append(path)
    if errors:
        print(f"{errors} arquivo(s) JSON com problema, de {len(files)} conferido(s).", file=sys.stderr)
        return 1

    if not has_check_jsonschema():
        print(
            "ERRO: check-jsonschema não encontrado. Instale com: pip install -r tools/ci/requirements.txt",
            file=sys.stderr,
        )
        return 1

    # 2. Os próprios schemas.
    schema_files = sorted((root / SCHEMAS_DIR).glob("*.schema.json"))
    if schema_files and run_check_jsonschema(
        ["--check-metaschema", *[str(path) for path in schema_files]]
    ):
        errors += 1

    # 3. Conteúdo contra os schemas.
    for schema_file, instances in sorted(groups.items()):
        print(f"== {schema_file.name}: {len(instances)} arquivo(s)")
        if run_check_jsonschema(["--schemafile", str(schema_file), *[str(p) for p in instances]]):
            errors += 1

    if errors:
        print("Validação de conteúdo falhou (veja acima).", file=sys.stderr)
        return 1
    validated = sum(len(instances) for instances in groups.values())
    print(f"Conteúdo OK: {len(files)} arquivo(s) JSON válido(s); {validated} conferido(s) com schema.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
