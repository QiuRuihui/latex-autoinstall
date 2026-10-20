#!/usr/bin/env bash
# 卸载 latex-autoinstall:移除符号链接
set -euo pipefail

bindir="${XDG_BIN_HOME:-$HOME/.local/bin}"

for e in xelatex pdflatex lualatex; do
    if [ -L "$bindir/$e" ] && [ "$(readlink "$bindir/$e")" = "latex-autoinstall" ]; then
        rm -f "$bindir/$e"
        echo "已移除 $bindir/$e"
    fi
done

if [ -f "$bindir/latex-autoinstall" ]; then
    rm -f "$bindir/latex-autoinstall"
    echo "已移除 $bindir/latex-autoinstall"
fi

echo "卸载完成。已下载到 ~/texmf 的宏包仍然保留,如需清理请手动删除。"
