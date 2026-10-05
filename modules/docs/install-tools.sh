#!/bin/sh
# Install the external tools used by modules/docs into ~/.local (no root).
# Tools already on PATH are skipped; delete one to reinstall/update it.
#   marksman, ltex-ls-plus (bundles Java 21), vale >= 3.15
#   --mermaid: also mermaid-cli (mmdc), via npm
# ponytail: Linux glibc x86_64/aarch64 only; add asset names for other platforms.
set -eu

BIN="$HOME/.local/bin"
OPT="$HOME/.local/opt"
mkdir -p "$BIN" "$OPT"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  MARKSMAN=linux-x64   VALE=Linux_64-bit LTEX=linux-x64 ;;
  Linux-aarch64) MARKSMAN=linux-arm64 VALE=Linux_arm64  LTEX=linux-aarch64 ;;
  *) echo "Unsupported platform: $(uname -sm)" >&2; exit 1 ;;
esac

# Latest release tag of a GitHub repository, from the releases/latest redirect.
latest() {
  curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's|.*/tag/||'
}

if command -v marksman >/dev/null; then
  echo "marksman: already installed ($(command -v marksman))"
else
  echo "marksman: downloading"
  curl -fL -o "$BIN/marksman.part" \
    "https://github.com/artempyanykh/marksman/releases/latest/download/marksman-$MARKSMAN"
  chmod +x "$BIN/marksman.part"
  mv "$BIN/marksman.part" "$BIN/marksman"
fi

if command -v ltex-ls-plus >/dev/null; then
  echo "ltex-ls-plus: already installed ($(command -v ltex-ls-plus))"
else
  version=$(latest ltex-plus/ltex-ls-plus)
  echo "ltex-ls-plus: downloading $version"
  curl -fL "https://github.com/ltex-plus/ltex-ls-plus/releases/download/$version/ltex-ls-plus-$version-$LTEX.tar.gz" \
    | tar xz -C "$OPT"
  ln -sf "$OPT/ltex-ls-plus-$version/bin/ltex-ls-plus" "$BIN/ltex-ls-plus"
fi

# Vale before 3.15 lacks --path and can only check saved files.
if command -v vale >/dev/null && vale --help 2>&1 | grep -q -- '--path'; then
  echo "vale: already installed ($(command -v vale))"
else
  version=$(latest vale-cli/vale)
  echo "vale: downloading $version"
  curl -fL "https://github.com/vale-cli/vale/releases/download/$version/vale_${version#v}_$VALE.tar.gz" \
    | tar xz -C "$BIN" vale
fi

if [ "${1:-}" = --mermaid ]; then
  if command -v mmdc >/dev/null; then
    echo "mmdc: already installed ($(command -v mmdc))"
  else
    echo "mmdc: installing @mermaid-js/mermaid-cli with npm"
    npm install --global --prefix "$HOME/.local" @mermaid-js/mermaid-cli
  fi
fi

echo
echo "Installed into $BIN:"
for tool in marksman ltex-ls-plus vale mmdc; do
  [ -e "$BIN/$tool" ] && echo "  $tool"
done
echo "Restart Emacs (or M-x lsp-workspace-restart in open Markdown buffers)."
