# 无管理员权限开发机的插件链接预建（junction 不需要 Developer Mode）。
# 用法：powershell -NoProfile -File tool/setup_symlinks.ps1 （在 app/ 目录执行后，再 flutter pub get）
$ErrorActionPreference = 'Stop'
$depsFile = '.flutter-plugins-dependencies'
if (-not (Test-Path $depsFile)) { throw "缺少 $depsFile，请先运行一次 flutter pub get（允许其在链接步骤失败）" }
$deps = Get-Content $depsFile -Raw | ConvertFrom-Json
$linkDir = 'windows/flutter/ephemeral/.plugin_symlinks'
New-Item -ItemType Directory -Force -Path $linkDir | Out-Null
foreach ($platform in @('windows', 'android')) {
  $plugins = $deps.plugins.$platform
  if ($null -eq $plugins) { continue }
  foreach ($p in $plugins) {
    $name = $p.name
    $target = ([string]$p.path).TrimEnd('\')
    if (-not (Test-Path "$linkDir\$name")) {
      New-Item -ItemType Junction -Path "$linkDir\$name" -Target $target | Out-Null
      Write-Output "JUNCTION $name -> $target"
    } else {
      Write-Output "EXISTS   $name"
    }
  }
}
Write-Output '完成：现在可以重新运行 flutter pub get / flutter build windows'
