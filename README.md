# Gaayana — Cross-platform Music Player

A Flutter (Android + iOS) music player inspired by Apple Music / JioSaavn / Spotify.

A pre-built release APK is committed at [`Gaayana.apk`](Gaayana.apk) (arm64 + armv7 + x86_64 fat APK, ~56 MB).

- Background playback + lock-screen / notification controls
- Bluetooth & headset detection with auto-route switching
- Offline downloads, sleep timer with fade-out
- Infinity radio (Last.fm + local play-count hybrid ranking)
- Single-track loop & playlist loop, shuffle, gapless, crossfade
- Playlists & favorites (cloud-synced via Firebase)
- Synced lyrics (LRCLIB)
- Equalizer stub, home-screen widget plumbing, share song
- Material You dynamic color extracted from album art
- Login via Google / Apple / Email magic link (no password signup)

## Already done (automated)

- Flutter SDK 3.41.9 installed at `V:\dev\flutter` (in user PATH)
- All Dart sources written (35 files) — `flutter analyze lib` → **0 errors**
- `flutter pub get` resolved 154 packages
- Android scaffolding generated, manifest overlaid (audio-service + Bluetooth + media-button + foreground-service-mediaPlayback)
- `minSdk = 23`, `multiDexEnabled = true`, `applicationId = com.newproj`
- Android SDK installed at `V:\dev\android-sdk` (platform-tools, android-34, android-36, build-tools 34/36, NDK 28, CMake 3.22)
- JDK 21 from Android Studio used (`JAVA_HOME` set persistently)
- **`flutter build apk --debug` succeeded** → `build/app/outputs/flutter-apk/app-debug.apk` (167 MB)
- `flutter doctor` → all green (Windows; macOS-only CocoaPods notice ignored)

### Plugin patch applied (transparent, but you should know)

`on_audio_query_android` 1.1.0 is pre-AGP-8 and required a one-time patch in the pub cache:

```
C:\Users\<you>\AppData\Local\Pub\Cache\hosted\pub.dev\on_audio_query_android-1.1.0\android\build.gradle
```
inside `android { … }` we added:
```gradle
namespace 'com.lucasjosino.on_audio_query'
compileOptions { sourceCompatibility JavaVersion.VERSION_1_8; targetCompatibility JavaVersion.VERSION_1_8 }
kotlinOptions { jvmTarget = '1.8' }
```
and bumped `minSdkVersion` from 16 to 19. Re-apply if you ever run `flutter pub cache repair`. Long-term: migrate to the `on_audio_query_pluse` fork.

## Remaining manual steps

### 1. Run on a device / emulator

```powershell
flutter devices                  # see what's connected
flutter run                      # builds + installs + hot-reload
```

If you don't have an emulator yet:
```powershell
& "V:\dev\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat" "system-images;android-34;google_apis;x86_64"
& "V:\dev\android-sdk\cmdline-tools\latest\bin\avdmanager.bat" create avd -n pixel34 -k "system-images;android-34;google_apis;x86_64" -d pixel
& "V:\dev\android-sdk\emulator\emulator.exe" -avd pixel34
```

### 2. Set up Firebase (for login + cloud sync)

```powershell
dart pub global activate flutterfire_cli
# Make sure %USERPROFILE%\AppData\Local\Pub\Cache\bin is on PATH
flutterfire configure
```

This opens a browser for Google sign-in, lets you pick / create a Firebase project, registers the Android (and iOS) app, downloads `google-services.json` to `android/app/`, and generates `lib/firebase_options.dart`. Then in `lib/main.dart` change:

```dart
await Firebase.initializeApp();
```
to:
```dart
import 'firebase_options.dart';
...
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

In the Firebase Console (https://console.firebase.google.com):

- **Authentication > Sign-in method**: enable **Google**, **Apple**, **Email link (passwordless)**
- **Firestore Database**: create in production mode, add security rule:

```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth.uid == uid;
}
```

### 3. Last.fm API key (for infinity-radio)

Register a free key at https://www.last.fm/api/account/create, then either:

- Enter it in **Settings > Last.fm API key** at runtime, or
- Run with `flutter run --dart-define=LASTFM_API_KEY=YOUR_KEY`

### 4. iOS (requires macOS)

```bash
cd v:/temp/NewProj
cp platform_overrides/ios/Runner/Info.plist ios/Runner/Info.plist
cd ios && pod install && cd ..
flutter run
```

Apple Developer account ($99/yr) required for App Store + CarPlay. CarPlay needs special Apple approval (apply early — can take weeks).

## Architecture

```
lib/
  app/                  MaterialApp, router, theme
  core/
    audio/              AudioHandler, RouteWatcher, SleepTimer
    db/                 SQLite schema + DAOs
    firebase/           Auth & Firestore sync
    music_source/       MusicSource interface + LocalFileSource
    network/            Last.fm + LRCLIB clients
  features/
    auth, library, player, playlists, favorites, search,
    downloads, radio, lyrics, sleep_timer, settings
  shared/               Reusable widgets
```

The `MusicSource` interface lets us swap the music origin (local files, Jamendo, Subsonic, etc.) without touching the UI. The first implementation, `LocalFileSource`, scans the device library and supports import via file picker — fully legal and fully offline.

## License

Personal / family / friends use.
