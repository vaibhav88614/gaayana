# One-shot project bootstrap for Gaayana on a fresh Windows machine.
#
# Usage (from project root):
#   pwsh -ExecutionPolicy Bypass -File tool\setup.ps1
#
# What it does:
#   1. Verifies prerequisites (git, git-lfs, flutter, java)
#   2. Runs `flutter pub get`
#   3. Re-applies the on_audio_query_android pub-cache patch
#   4. Reports `flutter doctor` summary
#
# It does NOT install Flutter / Android Studio / JDK for you — those need to
# be installed once via winget or the official installers (see docs/SETUP.md).

$ErrorActionPreference = 'Stop'

function Need($name, $hint) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host "[X] $name not found on PATH. $hint" -ForegroundColor Red
    return $false
  }
  Write-Host "[OK] $name : $($cmd.Source)" -ForegroundColor Green
  return $true
}

$ok = $true
$ok = (Need 'git'     "Install: winget install --id Git.Git")     -and $ok
$ok = (Need 'git-lfs' "Install: winget install --id GitHub.GitLFS; then run 'git lfs install'") -and $ok
$ok = (Need 'flutter' "Install Flutter SDK, add its bin\ to PATH") -and $ok
$ok = (Need 'java'    "Install Android Studio (bundles JBR); set JAVA_HOME") -and $ok
$ok = (Need 'adb'     "Install Android platform-tools; add to PATH")     -and $ok
if (-not $ok) { Write-Error "Missing prerequisites. Fix the above and re-run."; exit 1 }

Write-Host "`n== flutter pub get ==" -ForegroundColor Cyan
flutter pub get

Write-Host "`n== patching on_audio_query_android ==" -ForegroundColor Cyan
$patchScript = Join-Path $PSScriptRoot 'patch_pub_cache.ps1'
& powershell -ExecutionPolicy Bypass -File $patchScript

Write-Host "`n== flutter doctor ==" -ForegroundColor Cyan
flutter doctor

Write-Host "`nSetup complete. Run:" -ForegroundColor Green
Write-Host "  flutter run                     # debug on connected device/emulator"
Write-Host "  flutter build apk --release     # release APK"
