# One-stop Windows build prerequisites (ASCII only for PS 5.1 compatibility).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File tool/setup_windows_build.ps1
$ErrorActionPreference = 'Stop'

Write-Output '== 1/3 Plugin junction links (no admin needed) =='
& (Join-Path $PSScriptRoot 'setup_symlinks.ps1')

Write-Output '== 2/3 sqlite3.dll for flutter test (bundled inside packaged app) =='
$flutterWhich = (Get-Command flutter -ErrorAction SilentlyContinue).Source
$targets = @()
if ($flutterWhich) { $targets += (Split-Path $flutterWhich) }
$targets += "$env:LOCALAPPDATA\Microsoft\WindowsApps"
$dllPlaced = $false
foreach ($t in $targets) {
  if ((Test-Path $t) -and (Test-Path (Join-Path $t 'sqlite3.dll'))) { $dllPlaced = $true; break }
}
if ($dllPlaced) {
  Write-Output 'sqlite3.dll already present in PATH.'
} else {
  $ver = '3530400'
  $url = "https://www.sqlite.org/2026/sqlite-dll-win-x64-$ver.zip"
  $tmp = Join-Path $env:TEMP "sqlite3-dll-$ver"
  Invoke-WebRequest -Uri $url -OutFile "$tmp.zip"
  Expand-Archive "$tmp.zip" -DestinationPath $tmp -Force
  $placed = $false
  foreach ($t in $targets) {
    try {
      Copy-Item "$tmp\sqlite3.dll" $t -Force
      Write-Output "sqlite3.dll -> $t"
      $placed = $true
      break
    } catch { continue }
  }
  Remove-Item "$tmp.zip", $tmp -Recurse -Force -ErrorAction SilentlyContinue
  if (-not $placed) { throw 'Could not place sqlite3.dll into any PATH directory.' }
}

Write-Output '== 3/3 nuget.exe for flutter_inappwebview_windows (WebView2 SDK) =='
if (Get-Command nuget -ErrorAction SilentlyContinue) {
  Write-Output 'nuget already available in PATH.'
} else {
  New-Item -ItemType Directory -Force -Path 'C:\dev\tools' | Out-Null
  Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile 'C:\dev\tools\nuget.exe'
  try {
    Copy-Item 'C:\dev\tools\nuget.exe' "$env:LOCALAPPDATA\Microsoft\WindowsApps\nuget.exe" -Force
    Write-Output 'nuget.exe installed (C:\dev\tools and WindowsApps).'
  } catch {
    Write-Output 'nuget.exe downloaded to C:\dev\tools; add it to PATH before building Windows.'
  }
}

Write-Output 'All prerequisites ready.'
