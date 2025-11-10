# Rust 开发环境准备文档
- 此文档由 ChatGPT 生成
> 目标：在常见平台（macOS / Linux / Windows / WSL）上快速搭建可用的 Rust 开发环境，并在有网络受限或下载缓慢时给出镜像与代理的可操作配置。

---

## 1. 前置条件（按平台）

* macOS：建议安装 Homebrew（可选），系统应能运行 `curl` 与 `bash`。
* Linux：基本 shell、`curl`/`wget`、`tar` 可用；Debian/Ubuntu 建议先安装 `build-essential`。
* Windows：推荐使用 **Windows 10/11 + WSL2**（Ubuntu 等），或直接安装 rustup 的 Windows 安装器；若使用 MSVC 工具链，需安装 Visual Studio 的 C++ 工具集。

## 2. 推荐安装方式（官方推荐）

1. 使用 rustup 安装（会安装 `rustc`、`cargo`、`rustup`）：

```bash
# Unix/macOS/WSL（推荐）
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 按提示选择默认 stable 工具链
```

2. 完成安装后，确保 `$HOME/.cargo/bin`（Windows 为 `%USERPROFILE%\\.cargo\\bin`）在你的 PATH 中；重开终端后运行：

```bash
rustc --version
cargo --version
rustup show
```

（如果报错请检查 PATH）

## 3. 常用组件与工具（推荐安装）

* `rust-analyzer`（语言服务器）——VSCode / Neovim 等编辑器插件，用于智能补全、跳转。
* `clippy`：静态代码检查工具，安装并启用 `rustup component add clippy`。
* `rustfmt`：代码格式化，`rustup component add rustfmt`。
* `cargo-edit`：方便的 `cargo add` / `cargo rm` / `cargo upgrade`（`cargo install cargo-edit`）。
* `cargo-watch`、`cargo-make` 等：提高开发效率的工具（按需安装）。

示例：

```bash
rustup component add clippy rustfmt
cargo install cargo-edit cargo-watch
```

## 4. 编辑器配置（快速）

* VSCode + Rust Analyzer（扩展 `rust-analyzer`）——最常见组合。
* Neovim + coc.nvim / nvim-lspconfig + rust-analyzer 也很流畅。

---

## 5. 在网络受限 / 国内加速场景下：镜像与代理（实用）

### 5.1 rustup（toolchain）使用镜像

**示例（Linux / macOS / WSL）**：

```bash
export RUSTUP_DIST_SERVER="https://mirrors.ustc.edu.cn/rust-static"
export RUSTUP_UPDATE_ROOT="https://mirrors.ustc.edu.cn/rust-static/rustup"

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

**示例（Windows PowerShell，永久设为用户变量）**：

```powershell
[System.Environment]::SetEnvironmentVariable("RUSTUP_DIST_SERVER", "https://mirrors.ustc.edu.cn/rust-static", 'User')
[System.Environment]::SetEnvironmentVariable("RUSTUP_UPDATE_ROOT", "https://mirrors.ustc.edu.cn/rust-static/rustup", 'User')
```

### 5.2 Cargo（crates.io 索引与 crate 下载）使用国内镜像

**全局配置示例**：

```toml
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"

[registries.ustc]
index = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
```

**注意事项**：

* `replace-with` 将默认的 `crates-io` 替换为 `ustc`。
* `registry`/`index` 的 URL 以镜像提供方说明为准。

### 5.3 通用 HTTP(S) 代理

**示例（临时代理）**：

```bash
HTTPS_PROXY="http://127.0.0.1:7890" cargo build
```

**或在配置文件中**：

```toml
[http]
proxy = "http://127.0.0.1:7890"
```

---

## 6. 常见问题与排查技巧

* **索引更新慢或卡住**：优先尝试配置镜像或删除索引缓存。
* **证书错误**：检查代理的 TLS 配置。
* **发布到 crates.io 失败**：检查是否使用了替代源。

## 7. 一键检查脚本

```bash
set -e
echo "Rustc: " $(rustc --version || echo "not installed")
echo "Cargo: " $(cargo --version || echo "not installed")
echo "Rustup: " $(rustup --version || echo "not installed")
command -v cargo || echo "Warning: cargo not in PATH"
rustup component list --installed || true
```

---

## 8. 推荐阅读

* Rust 官方网站：[https://www.rust-lang.org](https://www.rust-lang.org)
* rustup 文档：[https://rust-lang.github.io/rustup](https://rust-lang.github.io/rustup)
* Cargo 文档：[https://doc.rust-lang.org/cargo](https://doc.rust-lang.org/cargo)
* USTC 镜像使用说明：[https://mirrors.ustc.edu.cn/help/rust-static.html](https://mirrors.ustc.edu.cn/help/rust-static.html)

---

## 9. 最小可行步骤速查

1. 安装 rustup 并确认可用。
2. 安装 `clippy`、`rustfmt`、`rust-analyzer`。
3. 配置国内镜像（`RUSTUP_DIST_SERVER`、`CARGO_HOME/config.toml`）。
4. 必要时使用 HTTP(S) 代理。

---

### 附：常用命令速览

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add clippy rustfmt
rustup update
HTTPS_PROXY="http://127.0.0.1:7890" cargo build
```

## 10. 更新 rust
```bash
rustup update
```

## 11. 或者使用已经写好的自动安装脚本：
[Rust 环境一键安装脚本](install-rust-windows.ps1)
