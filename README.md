# latex-autoinstall

> 让 TeX Live 在编译时自动下载缺失的宏包。

在 TeXstudio 或 VS Code 中写 LaTeX 时,最烦的报错大概就是:

```
! LaTeX Error: File `fontawesome5.sty' not found.
```

MiKTeX 会自动去装,Tectonic 会按需下载,而 **TeX Live 不会**——尤其在 Debian/Ubuntu 上,`tlmgr` 被限制成 user mode,系统包又必须走 `apt`,于是每次遇到冷门宏包都得手动查、手动装、再重新编译。

本项目把 `tlmgr` 的用户模式包装成 `xelatex` / `pdflatex` / `lualatex`,编译时发现缺包就自动装进 `~/texmf`,然后自动重编。**编辑器不需要任何额外配置**。

## 工作原理

```
            ┌──────────────────────────────┐
xelatex ───▶│  latex-autoinstall (wrapper)  │
pdflatex ──▶│                              │
lualatex ──▶└──────────────┬───────────────┘
                           │ 1. 调用真实引擎 /usr/bin/<engine>
                           ▼
                 ┌───────────────────┐
                 │ 编译成功?          │──是──▶ 输出 PDF,结束
                 └─────────┬─────────┘
                           否
                           ▼
             2. 从日志抓取 "File `xxx.sty' not found"
                           ▼
             3. tlmgr --usermode install xxx  (装入 ~/texmf)
                           ▼
             4. kpsewhich 验证文件确实可见
                           ▼
             5. 重新编译(最多 8 轮)
```

几个关键点:

- **不只看 tlmgr 的退出码。** 实测中 tlmgr 可能出现「报告失败但返回 0」的情况,因此安装后一律用 `kpsewhich <文件>` 验证真实结果。
- **自动匹配仓库。** 通过 `tlmgr --version` 读出 TeX Live 年份,优先使用对应的冻结版历史仓库(`tlnet-final`),失败再回退到 `mirror.ctan.org` 的 `tlnet`。
- **多轮补齐依赖。** LaTeX 一次只报第一个缺失文件,所以包装器会一轮一轮地装,直到编译通过或达到上限。

## 环境要求

- Linux(主要针对 **Debian / Ubuntu**;上游 TeX Live 未经测试,见「已知限制」)
- 已安装 TeX Live,且 `tlmgr` 可用
- `~/.local/bin` 在 `PATH` 中(Ubuntu 桌面版默认满足)

## 安装

一条命令完成安装(克隆到当前目录并建立符号链接):

```bash
git clone https://github.com/QiuRuihui/latex-autoinstall.git && cd latex-autoinstall && ./install.sh
```

> 仓库是私有的,执行前需要你本机已登录 GitHub(浏览器登录的凭据不通用,请先跑一次 `gh auth login`,或使用带访问权限的 HTTPS 凭据)。

如果已经装过 `gh`,也可以用:

```bash
gh repo clone QiuRuihui/latex-autoinstall && cd latex-autoinstall && ./install.sh
```

### 分步安装

```bash
git clone https://github.com/QiuRuihui/latex-autoinstall.git
cd latex-autoinstall
./install.sh
```

`install.sh` 会:

1. 把 `latex-autoinstall` 复制到 `~/.local/bin/`
2. 创建三个符号链接:`xelatex`、`pdflatex`、`lualatex`
3. 检查 `~/.local/bin` 是否在 `PATH` 中

> `~/.local/bin` 在标准路径里排在 `/usr/bin` 之前,所以它会自动覆盖同名编译器。VS Code(包括 snap 版)和 TeXstudio 的 `PATH` 都遵循这一顺序,因此两者无需任何配置即可生效。

### 更新

```bash
cd latex-autoinstall && git pull && ./install.sh
```

验证:

```bash
command -v xelatex
# 应输出 /home/<你>/.local/bin/xelatex
```

## 使用

正常编译即可。缺包时你会看到:

```
! LaTeX Error: File `academicons.sty' not found.
latex-autoinstall: 缺少 academicons.sty,正在安装宏包 'academicons' ...
latex-autoinstall: 宏包就绪,重新编译(第 2 轮)...
Output written on t.pdf (1 page).
```

- **VS Code**:直接保存文件(LaTeX Workshop 会调用 `latexmk -xelatex`,而 `latexmk` 又从 `PATH` 找 `xelatex`,自然经过包装器)。
- **TeXstudio**:按 `F5` 编译即可。若默认编译器不是 XeLaTeX,请在「选项 → 配置 TeXstudio → 构建 → 默认编译器」中修改。

## 配置项

| 环境变量 | 默认值 | 说明 |
|---|---|---|
| `TEX_AUTOINSTALL_REPO` | 自动检测 | 手动指定仓库地址,优先级最高 |
| `TEX_AUTOINSTALL_ROUNDS` | `8` | 最多安装/重编轮数 |
| `TEX_AUTOINSTALL_TIMEOUT` | `180` | 单次 `tlmgr install` 的超时秒数 |
| `TEX_AUTOINSTALL_OFF` | 未设置 | 设为 `1` 则完全禁用,退化为直接调用引擎 |

示例:

```bash
# 临时关闭自动下载(当前 shell 有效)
export TEX_AUTOINSTALL_OFF=1

# 改用国内镜像(注意:冻结版历史仓库通常只有官方源)
export TEX_AUTOINSTALL_REPO=https://mirror.ctan.org/systems/texlive/tlnet
```

## 已知限制

1. **只处理「文件未找到」类错误。** 触发条件是日志中的 `File 'xxx' not found`,即 `.sty`、`.cls`、`.def`、`.fd`、`.bbx` 等文件缺失。宏包选项冲突、字体找不到、语法错误都不会自动修复。
2. **安装位置是 `~/texmf`,会覆盖系统包。** Debian 官方文档明确不建议使用 tlmgr 用户模式:装进用户树的包优先级高于系统树,后续 `apt upgrade` 更新系统里的同一宏包时,用户树里的旧版本仍然生效。
3. **冻结版仓库的签名密钥会过期。** TeX Live 每年冻结后,`tlnet-final` 的 GPG 密钥随之过期,tlmgr 会提示 `valid signature with expired key`。下载仍走 HTTPS,但完整性校验强度低于正常时期。
4. **首次安装较慢。** 单个宏包通常 20~40 秒;带字体映射的包会额外运行 `updmap-user`。安装过一次后就会本地缓存。
5. **上游 TeX Live 未测试。** 如果你是用 `install-tl` 自己装的 TeX Live,`tlmgr` 默认是系统级、需要 root,本项目的 `--usermode` 假设不成立。此时请改用 `texliveonfly` 之类的方案,或自行调整脚本。
6. **不是所有宏包都能装在用户树。** 需要重建格式、依赖系统二进制的包可能安装失败,脚本会打印 `无法自动安装 xxx`。

## 安全说明

自动下载意味着**编译文档时会从网络拉取并执行第三方包内容**(tlmgr 的部分安装后动作会执行脚本)。这与 `tlmgr install` 手动安装的信任模型一致,但请注意:

- 只在你信任的仓库上使用;
- 打开来路不明的 `.tex` 文件时,建议临时设置 `TEX_AUTOINSTALL_OFF=1`;
- 不需要此功能时,直接卸载即可。

## 卸载

```bash
./uninstall.sh
```

这会移除 `~/.local/bin` 下的包装器和三个符号链接。已下载到 `~/texmf` 的宏包不会删除;如需清理:

```bash
rm -rf ~/texmf/tex/latex/<包名>
mktexlsr ~/texmf
```

## 故障排查

| 现象 | 处理 |
|---|---|
| `command -v xelatex` 仍指向 `/usr/bin/xelatex` | `~/.local/bin` 不在 `PATH` 前面;把它加进 `~/.profile` 并重新登录 |
| 提示 `tlmgr: user mode not initialized` | 运行 `tlmgr init-usertree`(脚本会尝试自动执行) |
| 一直停在 `正在安装宏包` | 网络问题;可换仓库或调大 `TEX_AUTOINSTALL_TIMEOUT` |
| 安装成功但编译仍报找不到 | 执行 `mktexlsr ~/texmf`,再确认 `kpsewhich xxx.sty` 的路径 |
| 包名猜测失败 | 脚本会调用 `tlmgr search --global --file` 反查,较慢;也可用 `apt-file search xxx.sty` 手动定位 |

## 测试环境

- Ubuntu 26.04 (Resolute Raccoon)
- TeX Live 2025(来自 Ubuntu 仓库)
- TeXstudio 4.9.1 / VS Code 1.142.0 + LaTeX Workshop 10.20.0

已验证场景:缺单个包自动安装、经 `latexmk` 调用、多依赖链逐轮补齐、包已存在时无额外开销。

## 许可证

[MIT](LICENSE)
