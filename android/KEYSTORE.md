# Release keystore (Android)

All Uniro updates — Play Store, GitHub Releases APKs, and the in-app OTA
updater — must be signed with the **same** key. A different key means
Android refuses to install the update (signature mismatch, no override).

## Create once (maintainer only)

Run this **yourself** on your machine — do NOT ask anyone to run it for
you, and never share the resulting files or passwords in chat, email,
or the repo.

```powershell
# JDK ships keytool; run from any folder, then move the .jks next to the app:
keytool -genkeypair -v `
  -keystore uniro-release.jks `
  -alias uniro `
  -keyalg RSA -keysize 2048 -validity 10000
```

Pick a strong store password AND a strong (different) key password.
Then create `android/key.properties` (the `android/` folder itself,
next to `android/app/`):

```properties
storeFile=../uniro-release.jks
storePassword=PASTE_STORE_PASSWORD_HERE
keyAlias=uniro
keyPassword=PASTE_KEY_PASSWORD_HERE
```

`key.properties` and `*.jks` are in `.gitignore` — verify with
`git status` that they never appear as staged files.

## Back up in TWO places, today

1. An encrypted USB drive or password manager attachment, AND
2. A second independent location (another machine, sealed envelope, …).

**If the keystore or either password is lost, there is no recovery:**
you can never ship another update under the same app id — every user
must uninstall and reinstall, losing all local data.

## Verify before every release

```powershell
# 1. Confirm the APK carries YOUR cert (compare with the previous release):
& "$env:ANDROID_HOME\build-tools\<version>\apksigner.bat" verify --print-certs `
  build\app\outputs\flutter-apk\app-arm64-v8a-release.apk

# 2. OTA check: install the previous release on a device, then install
#    this build over it (same key → must succeed, data kept):
adb install -r build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
# Then open the app → Profile → Check for updates against the matching
# GitHub Release to prove the full OTA loop with this key.
```

## Contributors

No keystore needed: without `android/key.properties` the release
buildType silently falls back to the debug key so you can still build
and test. Never ship those APKs to testers or Releases.
