#!/usr/bin/env bash
# Instala o Blender (Linux x86_64) na versão de .blender-version. Usado no CI (job do add-on).
#
# Uso: tools/ci/install_blender.sh
#
# Instala em ~/.local/share/blender/ (ou $BLENDER_INSTALL_DIR) e cria o atalho
# ~/.local/bin/blender. Confere o SHA-256 publicado em download.blender.org. Idempotente.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

[ "$(uname -s)" = "Linux" ] || die "Este script só instala o Blender para Linux. No Windows, baixe em https://www.blender.org/download/lts/ e defina a variável BLENDER."
[ "$(uname -m)" = "x86_64" ] || die "Arquitetura não suportada: $(uname -m) (esperado x86_64)."
for tool in curl tar sha256sum; do
  command -v "$tool" > /dev/null 2>&1 || die "Ferramenta necessária não encontrada: $tool"
done

version="$BLENDER_VERSION_WANTED"
release_url="https://download.blender.org/release/Blender${version%.*}"
file="blender-${version}-linux-x64.tar.xz"
install_dir="${BLENDER_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/blender}"
target="$install_dir/blender-${version}-linux-x64"
link_dir="$HOME/.local/bin"

if [ ! -x "$target/blender" ]; then
  work_dir="$(mktemp -d)"
  trap 'rm -rf "$work_dir"' EXIT
  info "Baixando $file ..."
  curl --fail --silent --show-error --location --retry 3 -o "$work_dir/sums" "$release_url/blender-${version}.sha256"
  curl --fail --silent --show-error --location --retry 3 -o "$work_dir/$file" "$release_url/$file"
  expected="$(awk -v f="$file" '$2 == f { print $1 }' "$work_dir/sums")"
  [ -n "$expected" ] || die "SHA-256 de $file não encontrado em blender-${version}.sha256"
  actual="$(sha256sum "$work_dir/$file" | awk '{ print $1 }')"
  [ "$expected" = "$actual" ] || die "SHA-256 não confere para $file (esperado $expected, obtido $actual)"
  info "SHA-256 conferido."
  mkdir -p "$install_dir"
  tar -xJf "$work_dir/$file" -C "$install_dir"
fi

mkdir -p "$link_dir"
ln -sf "$target/blender" "$link_dir/blender"
info "Blender instalado: $("$link_dir/blender" --version 2> /dev/null | head -n 1)"
