<#
.SYNOPSIS
  Windows11 自动化安装 Rust 开发环境脚本（支持国内镜像与代理）
.PARAMETER UseMirror
  是否使用国内镜像（会设置 RUSTUP_DIST_SERVER / RUSTUP_UPDATE_ROOT 并生成 ~/.cargo/config.toml）
.PARAMETER Mirror
  镜像选择：'ustc'（默认） / 'tuna' / 'aliyun' / 或自定义镜像 base URL（用于 rustup/dist server 与 registry）
.PARAMETER Proxy
  可选 HTTP(S) 代理字符串，例如 "http://127.0.0.1:7890"
.PARAMETER InstallVSCode
  若指定，则通过 winget 安装 VSCode，并尝试安装 rust-analyzer 扩展（需 code CLI 在 PATH）
#>

param(
    [switch]$UseMirror,
    [string]$Mirror = "ustc",
    [string]$Proxy = "",
    [switch]$InstallVSCode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Log($msg) {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$ts] $msg"
}

# 确保用户目录可用
$UserProfile = $env:USERPROFILE
if (-not $UserProfile) { throw "无法读取 USERPROFILE 环境变量。" }

# 1) 可选：设置 rustup 镜像相关环境变量（用户级）
if ($UseMirror) {
    switch ($Mirror.ToLower()) {
        'ustc' {
            $rustupDist = "https://mirrors.ustc.edu.cn/rust-static"
            $rustupUpdate = "https://mirrors.ustc.edu.cn/rust-static/rustup"
            $cratesIndex = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
        }
        'tuna' {
            $rustupDist = "https://mirrors.tuna.tsinghua.edu.cn/rust-static"
            $rustupUpdate = "https://mirrors.tuna.tsinghua.edu.cn/rust-static/rustup"
            $cratesIndex = "sparse+https://mirrors.tuna.tsinghua.edu.cn/crates.io-index/"
        }
        'aliyun' {
            $rustupDist = "https://mirrors.aliyun.com/rust-static"
            $rustupUpdate = "https://mirrors.aliyun.com/rust-static/rustup"
            $cratesIndex = "sparse+https://mirrors.aliyun.com/crates.io-index/"
        }
        default {
            # 如果用户传入自定义镜像 base URL，尝试用它
            $base = $Mirror.TrimEnd('/')
            $rustupDist = "$base/rust-static"
            $rustupUpdate = "$base/rust-static/rustup"
            $cratesIndex = "sparse+$base/crates.io-index/"
        }
    }

    Write-Log "设置 RUSTUP_DIST_SERVER 与 RUSTUP_UPDATE_ROOT（用户环境）指向镜像： $Mirror"
    [System.Environment]::SetEnvironmentVariable("RUSTUP_DIST_SERVER", $rustupDist, "User")
    [System.Environment]::SetEnvironmentVariable("RUSTUP_UPDATE_ROOT", $rustupUpdate, "User")
}

# 2) 可选：设置 HTTP(S) 代理（用户级环境变量 + cargo config http.proxy）
if ($Proxy -ne "") {
    Write-Log "设置 HTTP(S) 代理为： $Proxy（用户环境变量）"
    [System.Environment]::SetEnvironmentVariable("HTTP_PROXY", $Proxy, "User")
    [System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", $Proxy, "User")
}

# 3) 下载并运行 rustup-init（使用 win.rustup.rs 重定向到 exe）
$TempExe = Join-Path $env:TEMP "rustup-init.exe"
Write-Log "下载 rustup-installer 到 $TempExe ..."
try {
    Invoke-WebRequest -Uri "https://win.rustup.rs/" -OutFile $TempExe -UseBasicParsing -ErrorAction Stop
}
catch {
    Write-Error "下载 rustup-installer 失败：$_"
    throw $_
}

# 自动接受默认安装 (-y)
Write-Log "运行 rustup-init （自动接受默认安装）..."
$startInfo = @{
    FilePath     = $TempExe
    ArgumentList = "-y"
    NoNewWindow  = $true
    Wait         = $true
}
Start-Process @startInfo

# 4) 确认 rustup / cargo 路径（可能需要刷新环境变量）
$cargoBin = Join-Path $UserProfile ".cargo\bin"
$rustupExe = Join-Path $cargoBin "rustup.exe"
$cargoExe = Join-Path $cargoBin "cargo.exe"
$rustcExe = Join-Path $cargoBin "rustc.exe"

if (-not (Test-Path $rustupExe)) {
    Write-Log "注意：rustup 未出现在 $cargoBin，请确认是否需要重新打开终端。脚本仍会尝试通过 PATH 调用。"
}

# Helper to run cargo/rustup if found in PATH or in $cargoBin
function Run-Exe($exeName, [string[]]$args) {
    $exePath = $null
    # 优先使用 $cargoBin 下的可执行文件
    $candidate = Join-Path $cargoBin $exeName
    if (Test-Path $candidate) { $exePath = $candidate }
    else {
        # 尝试从 PATH 中找到
        $exePath = (Get-Command $exeName -ErrorAction SilentlyContinue)?.Source
    }
    if (-not $exePath) {
        Write-Error "找不到 $exeName（既不在 $cargoBin，PATH 中也无法找到）。"
        return $false
    }
    & $exePath @args
    return $true
}

# 5) 生成 Cargo config（若使用镜像或设置了代理）
$cargoConfigPath = Join-Path $UserProfile ".cargo\config.toml"
if ($UseMirror -or ($Proxy -ne "")) {
    Write-Log "生成或更新 $cargoConfigPath"
    $configLines = @()

    if ($UseMirror) {
        $configLines += "[source.crates-io]"
        $configLines += "replace-with = 'mirror'"
        $configLines += ""
        $configLines += "[source.mirror]"
        $configLines += "registry = `"$cratesIndex`""
        $configLines += ""
        $configLines += "[registries.mirror]"
        $configLines += "index = `"$cratesIndex`""
        $configLines += ""
    }

    if ($Proxy -ne "") {
        $configLines += "[http]"
        $configLines += "proxy = `"$Proxy`""
        $configLines += ""
    }

    # 写入文件（备份原文件）
    if (Test-Path $cargoConfigPath) {
        Copy-Item $cargoConfigPath "${cargoConfigPath}.bak_$(Get-Date -Format yyyyMMddHHmmss)" -Force
        Write-Log "已备份旧的 config.toml"
    }
    else {
        $dir = Split-Path $cargoConfigPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    }

    $configLines -join "`n" | Out-File -FilePath $cargoConfigPath -Encoding UTF8 -Force
    Write-Log "写入 $cargoConfigPath 完成。"
}

# 6) 添加常用组件（clippy, rustfmt）
Write-Log "安装 common rustup components: clippy, rustfmt ..."
$ok = Run-Exe "rustup.exe" @("component", "add", "clippy", "rustfmt")
if (-not $ok) { Write-Log "尝试通过 PATH 运行 rustup 失败，请手动在新打开的终端运行： rustup component add clippy rustfmt" }

# 7) 安装常用 cargo 工具
$cargoTools = @("cargo-edit", "cargo-watch")
Write-Log "安装 cargo 工具： $($cargoTools -join ', ') ..."
$ok = Run-Exe "cargo.exe" @("install") 
# better to call multiple installs to handle absent cargo.exe gracefully
foreach ($t in $cargoTools) {
    $installed = Run-Exe "cargo.exe" @("install", $t)
    if (-not $installed) { Write-Log "警告：未能安装 $t，请确认 cargo 可用并重试。" }
}

# 8) 可选：安装 VSCode 并尝试安装 rust-analyzer 扩展
if ($InstallVSCode) {
    Write-Log "尝试通过 winget 安装 VSCode (若已安装则跳过)..."
    try {
        winget install --id Microsoft.VisualStudioCode -e --silent
    }
    catch {
        Write-Log "winget 安装 VSCode 失败或 winget 不可用：$_. 你也可以手动安装 VSCode。"
    }

    # 尝试使用 code CLI 安装扩展
    $codeCmd = (Get-Command code -ErrorAction SilentlyContinue)?.Source
    if (-not $codeCmd) {
        # 尝试 VSCode 安装目录的 code.cmd（可能位于 Program Files\Microsoft VS Code\bin）
        $possible = @(
            "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
            "$env:ProgramFiles(x86)\Microsoft VS Code\bin\code.cmd",
            "$env:LocalAppData\Programs\Microsoft VS Code\bin\code.cmd"
        )
        foreach ($p in $possible) { if (Test-Path $p) { $codeCmd = $p; break } }
    }

    if ($codeCmd) {
        Write-Log "使用 code CLI 安装 rust-analyzer 扩展..."
        & $codeCmd --install-extension rust-lang.rust-analyzer --force
    }
    else {
        Write-Log "code CLI 未找到，无法自动安装 rust-analyzer 扩展。请在 VSCode 中安装 rust-analyzer。"
    }
}

# 9) 完成提示
Write-Log "安装脚本执行结束。请注意："
Write-Host ""
Write-Host "  1) 如果你没有以管理员或新环境运行，可能需要重新打开 PowerShell/终端以使环境变量生效。"
Write-Host "  2) 验证安装："
Write-Host "       rustc --version"
Write-Host "       cargo --version"
Write-Host "       rustup show"
Write-Host "  3) 如果使用镜像并仍遇到问题，尝试手动运行："
Write-Host "       rustup update"
Write-Host "       cargo fetch"
Write-Host ""
Write-Log "结束。"
