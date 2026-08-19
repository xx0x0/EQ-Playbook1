<#
.SYNOPSIS
  创建一个领域专属的 Claude Code 对话工作区,含目录结构、CLAUDE.md 和桌面快捷方式。
.EXAMPLE
  .\new-workspace.ps1 -Domain reading
  .\new-workspace.ps1 -Domain career -Path "D:\ws\career" -ShortcutName "职业 对话"
#>
param(
  [Parameter(Mandatory=$true)][string]$Domain,
  [string]$Path,
  [string]$ShortcutName
)

if (-not $Path)         { $Path = Join-Path $env:USERPROFILE $Domain }
if (-not $ShortcutName) { $ShortcutName = "$Domain 对话" }

if (Test-Path $Path) {
  Write-Output "目录已存在,已停止,未覆盖任何内容: $Path"
  return
}

# --- 目录 ---
foreach ($d in @('.claude\agents','knowledge','state','material')) {
  New-Item -ItemType Directory -Force -Path (Join-Path $Path $d) | Out-Null
}

# --- CLAUDE.md ---
@"
# $Domain 工作区

> 全局规则照常生效,此处只写本领域附加规则。

## 每次对话开场

先读 ``state/`` 下的文件,拿到当前进展再回答。不要反问用户「你现在什么情况」——答案在文件里。

## 本领域回答规范

TODO:写死你在这个领域最容易被糊弄的地方。

## 目录分工

| 目录 | 放什么 | 进 git |
|---|---|---|
| ``knowledge/`` | 精炼后的结论、原则 | 是 |
| ``state/`` | 具体进展、判断 | 看仓库可见性 |
| ``material/`` | 原始素材,加工完可删 | 否 |

## 大批量原始材料

超过 50 行的原始记录,派 subagent 去啃,只把结论带回主窗口。

## 仓库可见性

TODO:标明 Public 还是 Private,以及什么绝不能外流 / 绝不能进来。
"@ | Out-File -FilePath (Join-Path $Path 'CLAUDE.md') -Encoding utf8

# --- .gitignore ---
@"
material/
*.local.md
Thumbs.db
desktop.ini
.DS_Store
"@ | Out-File -FilePath (Join-Path $Path '.gitignore') -Encoding utf8

'原始素材放这里,不进 git。' | Out-File -FilePath (Join-Path $Path 'material\README.md') -Encoding utf8

# --- 桌面快捷方式(绝对路径,不依赖 PATH) ---
$cmd = "$env:APPDATA\npm\claude.cmd"
if (Test-Path $cmd) {
  $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "$ShortcutName.lnk"
  if (Test-Path $lnk) {
    Write-Output "桌面已有同名快捷方式,跳过未覆盖: $lnk"
  } else {
    $ws = New-Object -ComObject WScript.Shell
    $s = $ws.CreateShortcut($lnk)
    $s.TargetPath = 'powershell.exe'
    $s.Arguments  = "-NoExit -Command `"& '$cmd'`""
    $s.WorkingDirectory = $Path
    $s.Description = "$Domain 专属对话窗口"
    $s.IconLocation = 'shell32.dll,168'
    $s.Save()
    Write-Output "快捷方式: $lnk"
  }
} else {
  Write-Output "找不到 claude.cmd,跳过快捷方式。先装: npm install -g @anthropic-ai/claude-code"
}

Write-Output "工作区: $Path"
Write-Output "下一步:编辑 CLAUDE.md 里的两处 TODO,然后双击快捷方式试试。"
