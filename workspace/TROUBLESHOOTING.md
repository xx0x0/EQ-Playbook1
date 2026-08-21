# 故障排查

## 报「禁止运行脚本」/ PSSecurityException

**症状：**

```
无法加载文件 ...\npm\claude.ps1，因为在此系统上禁止运行脚本。
+ CategoryInfo : SecurityError: (:) []，PSSecurityException
```

**原因：** Windows 客户端的 PowerShell 执行策略默认是 `Restricted`，禁止运行任何
`.ps1`。快捷方式跑 `powershell -Command "claude"` 时，PowerShell 优先解析到
`claude.ps1`，于是被挡。

**容易误判的一点：** 在 Windows Terminal 里敲 `claude` 明明是好的 —— 那是因为
那个 shell 的执行策略与快捷方式启动的进程不同，不代表策略没问题。

查当前策略（各作用域全是 `Undefined` 就等于 `Restricted`）：

```powershell
Get-ExecutionPolicy -List
```

**修复（推荐，不动任何系统安全设置）：** 让快捷方式改调 `claude.cmd` ——
`.cmd` 不受执行策略管辖：

```powershell
$name = '<你的快捷方式名>'
$dir  = '<你的工作区绝对路径>'
$cmd  = "$env:APPDATA\npm\claude.cmd"
$lnk  = Join-Path ([Environment]::GetFolderPath('Desktop')) "$name.lnk"
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut($lnk)
$s.TargetPath = 'powershell.exe'
$s.Arguments  = "-NoExit -Command `"& '$cmd'`""
$s.WorkingDirectory = $dir
$s.IconLocation = 'shell32.dll,168'
$s.Save()
```

`new-workspace.ps1` 建出来的快捷方式本来就是这个版本，不受此问题影响。

**替代修法（一劳永逸，但改了账户级安全设置）：**

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

之后所有 npm 全局安装的 `.ps1` 工具都能直接跑。`RemoteSigned` = 本地脚本放行、
网上下载的需签名，比 `Bypass` 稳妥。**这是改你的账户配置，想清楚再动。**

---

## 桌面快捷方式闪退 / 打不开

**症状:** 双击后黑窗一闪就没,或提示 `claude 不是内部或外部命令`。

**原因:** 快捷方式调用 PATH 里的 `claude`。重装 Node、npm 换目录、或 PATH 被清理后就找不到了。

### 一、诊断

```powershell
Get-Command claude -ErrorAction SilentlyContinue | Select-Object -Expand Source
```

| 输出 | 说明 | 下一步 |
|---|---|---|
| 有路径 | claude 还在,问题在快捷方式 | 第三步 |
| 空 | PATH 丢了 | 第二步 |

### 二、PATH 丢了

```powershell
Test-Path "$env:APPDATA\npm\claude.cmd"
```

**True** — 只是 PATH 没包含 npm 目录,补回去(当前用户,不需要管理员):

```powershell
$npm = "$env:APPDATA\npm"
$old = [Environment]::GetEnvironmentVariable('Path','User')
if ($old -notlike "*$npm*") {
  [Environment]::SetEnvironmentVariable('Path', "$old;$npm", 'User')
  Write-Output "已加入 PATH,重开终端生效"
}
```

**False** — Claude Code 没装或被卸载:`npm install -g @anthropic-ai/claude-code`

### 三、重建快捷方式(不依赖 PATH 的稳版)

直接指向 `claude.cmd` 绝对路径:

```powershell
$name = '<你的快捷方式名>'
$dir  = '<你的工作区绝对路径>'
$cmd  = "$env:APPDATA\npm\claude.cmd"
$lnk  = Join-Path ([Environment]::GetFolderPath('Desktop')) "$name.lnk"
$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut($lnk)
$s.TargetPath = 'powershell.exe'
$s.Arguments  = "-NoExit -Command `"& '$cmd'`""
$s.WorkingDirectory = $dir
$s.IconLocation = 'shell32.dll,168'
$s.Save()
```

> 注意桌面可能被 OneDrive 重定向,所以用 `[Environment]::GetFolderPath('Desktop')` 取真实路径,不要硬写用户目录下的 Desktop。

### 四、能打开但没进领域上下文

窗口开了,却反问你背景 —— 工作目录不对,`CLAUDE.md` 没加载。

右键快捷方式 → 属性 → **起始位置**必须是工作区绝对路径。

---

## 中文乱码

用 `Out-File` / `Set-Content` 写文件时显式加 `-Encoding utf8`。Windows PowerShell 5.1 的 `Set-Content` 默认用系统 ANSI 代码页,中文会变问号。
