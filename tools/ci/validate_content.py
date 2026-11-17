#!/usr/bin/env python3
"""Valida os arquivos JSON do projeto.

Etapa 00: confere apenas que todo .json é JSON válido (UTF-8, sem BOM, sem chaves
duplicadas). A validação contra os JSON Schemas de schemas/ entra na Etapa 01.

Uso: python tools/ci/validate_content.py [raiz_do_repositorio]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# Pastas (relativas à raiz) onde procurar arquivos .json.
SEARCH_DIRS = ("godot", "schemas")
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


def validate_file(path: Path) -> str | None:
    """Retorna a mensagem de erro, ou None se o arquivo for válido."""
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        return "arquivo com BOM (salve como UTF-8 sem BOM)"
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        return f"não é UTF-8 válido: {error}"
    try:
        json.loads(text, object_pairs_hook=_reject_duplicate_keys)
    except json.JSONDecodeError as error:
        return f"JSON inválido: {error.msg} (linha {error.lineno}, coluna {error.colno})"
    except ValueError as error:
        return str(error)
    return None


def main(argv: list[str]) -> int:
    root = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[2]
    files = find_json_files(root)
    errors = 0
    for path in files:
        message = validate_file(path)
        if message is not None:
            errors += 1
            print(f"ERRO: {path.relative_to(root).as_posix()}: {message}", file=sys.stderr)
    if errors:
        print(f"{errors} arquivo(s) JSON com problema, de {len(files)} conferido(s).", file=sys.stderr)
        return 1
    print(f"Conteúdo OK: {len(files)} arquivo(s) JSON válido(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
