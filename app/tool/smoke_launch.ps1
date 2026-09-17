# Smoke launch: run the release exe for 8 seconds and verify the process stays alive.
$exePath = Join-Path $PSScriptRoot '..\build\windows\x64\runner\Release\shoot_studio.exe'
if (-not (Test-Path $exePath)) { throw "Build artifact not found: $exePath" }
$p = Start-Process -FilePath $exePath -PassThru
Start-Sleep -Seconds 8
if (-not $p.HasExited) {
  Stop-Process -Id $p.Id -Force
  Write-Output 'LAUNCH-OK process alive (onboarding page)'
} else {
  Write-Output ("LAUNCH-FAIL exit=" + $p.ExitCode)
  exit 1
}
