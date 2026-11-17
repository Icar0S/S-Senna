#!/usr/bin/env bash
# Instala o Godot (Linux x86_64) na versão de .godot-version. Usado no CI e no ambiente do agente.
#
# Uso: tools/ci/install_godot.sh [--templates]
#   --templates   instala também os export templates (Linux e Windows x86_64).
#                 O arquivo tem ~1,3 GB; só é necessário para exportar builds.
#
# Instala em ~/.local/share/godot/ (ou $GODOT_INSTALL_DIR) e cria o atalho ~/.local/bin/godot.
# Confere o SHA-512 publicado em github.com/godotengine/godot-builds. Idempotente.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

want_templates=0
for arg in "$@"; do
  case "$arg" in
    --templates) want_templates=1 ;;
    -h | --help)
      sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Argumento desconhecido: $arg" ;;
  esac
done

[ "$(uname -s)" = "Linux" ] || die "Este script só instala o Godot para Linux. No Windows, baixe em https://godotengine.org/download e defina a variável GODOT."
[ "$(uname -m)" = "x86_64" ] || die "Arquitetura não suportada: $(uname -m) (esperado x86_64)."
for tool in curl unzip sha512sum; do
  command -v "$tool" > /dev/null 2>&1 || die "Ferramenta necessária não encontrada: $tool"
done

version="$GODOT_VERSION_WANTED"
release_url="https://github.com/godotengine/godot-builds/releases/download/${version}-stable"
install_dir="${GODOT_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/godot}"
bin_dir="$install_dir/bin"
bin_name="Godot_v${version}-stable_linux.x86_64"
templates_dir="$install_dir/export_templates/${version}.stable"
link_dir="$HOME/.local/bin"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

sums_file="$work_dir/SHA512-SUMS.txt"
fetch_sums() {
  [ -f "$sums_file" ] || curl --fail --silent --show-error --location --retry 3 -o "$sums_file" "$release_url/SHA512-SUMS.txt"
}

# Baixa $1 do release para $work_dir e confere o SHA-512.
download_verified() {
  local file="$1"
  fetch_sums
  info "Baixando $file ..."
  curl --fail --silent --show-error --location --retry 3 -o "$work_dir/$file" "$release_url/$file"
  local expected actual
  expected="$(awk -v f="$file" '$2 == f { print $1 }' "$sums_file")"
  [ -n "$expected" ] || die "SHA-512 de $file não encontrado em SHA512-SUMS.txt"
  actual="$(sha512sum "$work_dir/$file" | awk '{ print $1 }')"
  [ "$expected" = "$actual" ] || die "SHA-512 não confere para $file (esperado $expected, obtido $actual)"
  info "SHA-512 conferido."
}

if [ -x "$bin_dir/$bin_name" ]; then
  info "Godot $version já instalado em $bin_dir/$bin_name"
else
  download_verified "${bin_name}.zip"
  mkdir -p "$bin_dir"
  unzip -q -o "$work_dir/${bin_name}.zip" -d "$bin_dir"
  chmod +x "$bin_dir/$bin_name"
  rm -f "$work_dir/${bin_name}.zip"
  info "Godot $version instalado em $bin_dir/$bin_name"
fi

mkdir -p "$link_dir"
ln -sf "$bin_dir/$bin_name" "$link_dir/godot"

if [ "$want_templates" -eq 1 ]; then
  if [ -f "$templates_dir/version.txt" ] && [ -f "$templates_dir/linux_release.x86_64" ]; then
    info "Export templates $version já instalados em $templates_dir"
  else
    templates_file="Godot_v${version}-stable_export_templates.tpz"
    download_verified "$templates_file"
    mkdir -p "$templates_dir"
    # Só as plataformas dos presets do projeto (economiza ~1 GB de disco e de cache).
    unzip -q -o -j "$work_dir/$templates_file" \
      "templates/version.txt" \
      "templates/linux_debug.x86_64" "templates/linux_release.x86_64" \
      "templates/windows_debug_x86_64.exe" "templates/windows_release_x86_64.exe" \
      "templates/windows_debug_x86_64_console.exe" "templates/windows_release_x86_64_console.exe" \
      -d "$templates_dir"
    info "Export templates instalados em $templates_dir"
  fi
fi

# No GitHub Actions, deixa o `godot` disponível para os próximos passos do job.
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$link_dir" >> "$GITHUB_PATH"
fi

info "Pronto: $("$link_dir/godot" --version)"
case ":$PATH:" in
  *":$link_dir:"*) ;;
  *) info "Dica: adicione $link_dir ao PATH ou use GODOT=$link_dir/godot" ;;
esac
