# Setting up Gaayana on a new machine

This is what you need to do once on each computer that will build the app.

## 1. Install prerequisites (one-time)

```powershell
winget install --id Git.Git
winget install --id GitHub.GitLFS
git lfs install
winget install --id Google.AndroidStudio
```

Then download the Flutter SDK from <https://docs.flutter.dev/get-started/install/windows> and extract somewhere like `C:\dev\flutter`.

## 2. Set environment variables (one-time)

In PowerShell:

```powershell
[Environment]::SetEnvironmentVariable('JAVA_HOME', 'C:\Program Files\Android\Android Studio\jbr', 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', "$env:LOCALAPPDATA\Android\Sdk", 'User')

# Append to user PATH:
$p = [Environment]::GetEnvironmentVariable('Path', 'User')
$add = "C:\dev\flutter\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools;$env:LOCALAPPDATA\Android\Sdk\emulator"
[Environment]::SetEnvironmentVariable('Path', "$p;$add", 'User')
```

Close and reopen all terminals so the variables apply.

## 3. Install Android SDK components (one-time)

Open Android Studio → **More Actions → SDK Manager** and install:

- Android SDK Platform 34 (or newer)
- Android SDK Build-Tools
- Android SDK Platform-Tools
- Android Emulator
- A system image, e.g. *Android 14.0 Google APIs x86_64*

Then accept the licenses:

```powershell
flutter doctor --android-licenses
```

## 4. Clone the repo

```powershell
git clone https://github.com/vaibhav88614/gaayana.git
cd gaayana
```

Git LFS will automatically pull `Gaayana.apk` and the logo PNGs.

## 5. Bootstrap the project

```powershell
pwsh -ExecutionPolicy Bypass -File tool\setup.ps1
```

This runs `flutter pub get`, then patches the `on_audio_query_android` plugin in your Pub cache (it ships with an AGP-7 `build.gradle` that breaks under AGP 8 — the script adds a `namespace`, bumps `minSdk` to 19, and switches Java/Kotlin target to 1.8). Idempotent — safe to re-run.

If you ever run `flutter pub cache repair`, re-run:

```powershell
pwsh -ExecutionPolicy Bypass -File tool\patch_pub_cache.ps1
```

## 6. (Optional) Wire up Firebase

Skip if you don't want cloud sync — the app boots fine without it.

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-firebase-project-id>
```

This writes `lib/firebase_options.dart` and `android/app/google-services.json`. Both files are git-ignored, so each machine has its own.

## 7. Create an emulator (or plug in a phone)

```powershell
avdmanager create avd -n gaayana_test -k "system-images;android-34;google_apis;x86_64" -d pixel_6
emulator -avd gaayana_test
```

## 8. Run

```powershell
flutter run                            # debug build, hot reload
flutter build apk --release            # release APK at build\app\outputs\flutter-apk\app-release.apk
```

Or install the prebuilt:

```powershell
adb install -r Gaayana.apk
adb shell pm grant com.gaayana android.permission.READ_MEDIA_AUDIO
adb shell monkey -p com.gaayana -c android.intent.category.LAUNCHER 1
```

## 9. (Optional) Per-repo GitHub push credentials

Use a fine-grained Personal Access Token scoped to this repository only (<https://github.com/settings/personal-access-tokens>).

```powershell
git config --local credential.helper "store --file=.git/.git-credentials"
git config --local credential.useHttpPath true

$token = Read-Host -AsSecureString "Paste GitHub PAT"
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))
"https://x-access-token:$plain@github.com/vaibhav88614/gaayana.git" |
    Out-File -Encoding ascii .git\.git-credentials -NoNewline
$plain = $null
icacls .git\.git-credentials /inheritance:r /grant:r "$($env:USERNAME):(F)" | Out-Null
```

`.git/.git-credentials` is per-clone and never leaves this folder; nothing system-wide.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Namespace not specified` while building Android | Run `tool\patch_pub_cache.ps1` |
| `Daemon will be stopped at the end of the build` + Kotlin crashes | OK to ignore — just verbose noise |
| `READ_MEDIA_AUDIO not granted` and library is empty | `adb shell pm grant com.gaayana android.permission.READ_MEDIA_AUDIO` |
| Emulator hangs/dies during long sessions | `Get-Process emulator,qemu* \| Stop-Process -Force; emulator -avd <name>` |
| `Unable to find git-lfs filter-process` after clone | `winget install --id GitHub.GitLFS; git lfs install; git lfs pull` |
