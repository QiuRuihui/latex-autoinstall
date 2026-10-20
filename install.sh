#!/usr/bin/env bash
# 安装 latex-autoinstall:把包装器放到 ~/.local/bin 并建立引擎符号链接
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
bindir="${XDG_BIN_HOME:-$HOME/.local/bin}"

if ! command -v tlmgr >/dev/null 2>&1; then
    echo "错误:未找到 tlmgr。请先安装 TeX Live(如 sudo apt install texlive-latex-recommended)。" >&2
    exit 1
fi

mkdir -p "$bindir"
install -m 755 "$here/latex-autoinstall" "$bindir/latex-autoinstall"

for e in xelatex pdflatex lualatex; do
    ln -sf latex-autoinstall "$bindir/$e"
done

echo "已安装:"
for e in xelatex pdflatex lualatex; do
    printf '  %s -> %s\n' "$bindir/$e" "$(readlink -f "$bindir/$e")"
done

# PATH 检查
case ":$PATH:" in
    *":$bindir:"*)
        echo "PATH 检查: 通过,编译器调用会自动经过包装器。"
        ;;
    *)
        echo "警告: $bindir 不在当前 PATH 中,包装器不会生效。" >&2
        echo "请把下面这行加入 ~/.profile 后重新登录:" >&2
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
        ;;
esac

echo
echo "验证: command -v xelatex 应输出 $bindir/xelatex"
echo "卸载: $here/uninstall.sh"
