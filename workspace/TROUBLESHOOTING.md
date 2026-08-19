# 故障排查

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
