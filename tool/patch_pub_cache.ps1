# Re-apply the on_audio_query_android 1.1.0 patch in the local Pub cache.
#
# Published version of on_audio_query_android targets AGP 7. With AGP 8+ the
# build fails because it lacks a `namespace`, uses Java 1.6, and minSdk 16.
# This script idempotently patches the build.gradle in the pub cache.
#
# Re-run after:
#   - cloning the repo on a new machine
#   - `flutter pub cache repair`
#   - `flutter clean` + `flutter pub get` (sometimes)

$ErrorActionPreference = 'Stop'

$cacheRoots = @(
  "$env:LOCALAPPDATA\Pub\Cache",
  "$env:USERPROFILE\AppData\Roaming\Pub\Cache",
  "$env:APPDATA\Pub\Cache"
)
$gradle = $null
foreach ($root in $cacheRoots) {
  $cand = Join-Path $root 'hosted\pub.dev\on_audio_query_android-1.1.0\android\build.gradle'
  if (Test-Path $cand) { $gradle = $cand; break }
}
if (-not $gradle) {
  Write-Error "Could not find on_audio_query_android-1.1.0 in the pub cache. Run 'flutter pub get' first."
  exit 1
}
Write-Host "Patching $gradle"
$text = Get-Content $gradle -Raw

# 1) namespace
if ($text -notmatch "namespace\s+'com\.lucasjosino\.on_audio_query'") {
  $text = $text -replace "(android\s*\{)", "`$1`r`n    namespace 'com.lucasjosino.on_audio_query'"
  Write-Host "  + added namespace"
}

# 2) minSdk 16 -> 19
$text = $text -replace 'minSdkVersion\s+16', 'minSdkVersion 19'

# 3) Java/Kotlin target 1.6 -> 1.8 (only inside this module)
if ($text -notmatch 'sourceCompatibility\s+JavaVersion\.VERSION_1_8') {
  if ($text -match 'compileOptions\s*\{[^}]*\}') {
    $text = $text -replace 'compileOptions\s*\{[^}]*\}',
      "compileOptions {`r`n        sourceCompatibility JavaVersion.VERSION_1_8`r`n        targetCompatibility JavaVersion.VERSION_1_8`r`n    }"
  } else {
    $text = $text -replace '(defaultConfig\s*\{)',
      "compileOptions {`r`n        sourceCompatibility JavaVersion.VERSION_1_8`r`n        targetCompatibility JavaVersion.VERSION_1_8`r`n    }`r`n`r`n    `$1"
  }
  Write-Host "  + set compileOptions to Java 1.8"
}
if ($text -notmatch "jvmTarget\s*=\s*'1\.8'") {
  if ($text -match 'kotlinOptions\s*\{[^}]*\}') {
    $text = $text -replace 'kotlinOptions\s*\{[^}]*\}',
      "kotlinOptions {`r`n        jvmTarget = '1.8'`r`n    }"
  } else {
    $text = $text -replace '(compileOptions\s*\{[^}]*\})',
      "`$1`r`n`r`n    kotlinOptions {`r`n        jvmTarget = '1.8'`r`n    }"
  }
  Write-Host "  + set kotlinOptions jvmTarget 1.8"
}

Set-Content -Path $gradle -Value $text -Encoding UTF8 -NoNewline
Write-Host "Done."
