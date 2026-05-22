# Direct APK release

Direct APK builds are signed with the Dropweb production Android keystore and
distributed from `dropweb.org/download` outside Google Play. The build pipeline
must be airtight before any APK URL is published.

## Keystore and secret hygiene

- A **production keystore is required**. The release Gradle config is
  **fail-closed**: any release packaging task (`:app:assembleRelease`,
  `:app:bundleRelease`, `:app:installRelease`, `:app:packageRelease`,
  `:app:packageReleaseBundle`, `:app:signReleaseApk`, `:app:signReleaseBundle`)
  aborts up-front when the production signing inputs are missing. There is no
  debug-key fallback; release builds that cannot find the production keystore
  are not built at all. Debug builds and non-release Gradle tasks (analyze,
  test, IDE sync, `tasks`) continue to work without the production keystore.
- The signing config is loaded by `android/app/build.gradle.kts` from:
  - **Keystore file:** `android/app/keystore.jks` (must be a real regular
    file — a directory of the same name will not satisfy the check).
  - **Credentials:** the following keys in `android/local.properties`, each of
    which **must be present and non-blank** (empty or whitespace-only values
    are treated as missing and trigger the same fail-closed guard):
    - `storePassword=<your store password>`
    - `keyAlias=<your key alias>`
    - `keyPassword=<your key password>`
- **Never commit** any of the following to git, CI logs, screenshots, or chat:
  - `.jks` / `.keystore` files (including `android/app/keystore.jks`)
  - keystore passwords, key aliases, or key passwords
  - `android/local.properties`
  - `android/app/key.properties`, `signing.properties`, or any other file
    containing signing credentials
- Keep **at least two offline backups** of the production keystore (e.g. two
  encrypted offline drives in physically separate locations). Cloud-only copies
  do not count as a backup.
- **Losing the signing key permanently breaks updates** for every user who
  installed a previous direct APK: Android will refuse to install the new APK
  over the old one because the signing certificates will not match. There is no
  recovery path.
- Use the **same app signing key** if the same `applicationId` is later
  enrolled in Google Play. Switching keys means a new, separate app listing and
  no update path for existing direct-APK users.

## Release metadata published on `dropweb.org/download`

For every published direct APK, the download page and `latest.json` manifest
MUST expose:

- APK **SHA-256** of the exact `.apk` file being served.
- **Signing certificate SHA-256** (`apksigner verify --print-certs` →
  `Signer #1 certificate SHA-256 digest`).
- Exact Dropweb app **source URL/commit** (`sourceUrl`) and
  **source archive URL** (`sourceArchiveUrl`) — see
  `docs/release/source-availability.md` for the Task 10.5 source gate.
- Exact zencab cabinet **source URL/commit** (`cabinetSourceUrl`) when the
  APK depends on the served cabinet flows.
- License (`GPL-3.0` for the Dropweb app; the served cabinet frontend is
  AGPL-3.0 and is exposed via `cabinetSourceUrl`).
- Supported ABIs (`abi`) and minimum Android version (`minAndroid`).

A reference manifest shape lives at `tool/release/latest.example.json`. The
real `latest.json` is owned by the Dropweb website repo (Task 12), not this
repo.

## ABI scope

The current direct-APK pipeline builds **`arm64-v8a` only**
(`dart run setup.dart android --arch arm64`). The download page and release
manifest MUST state "Android ARM64 only" and MUST NOT imply universal APK
support (no `armeabi-v7a`, no `x86_64`, no fat/universal APK). Devices on other
ABIs will be unable to install the APK; that is intentional for this channel
and must be communicated honestly.

## Hard gates — do NOT publish if

- A release artifact was produced without the production signing config. The
  Gradle fail-closed guard prevents the silent debug-key fallback that used to
  exist here, so the practical failure mode is now "release task aborts before
  producing an APK/AAB". Treat any successful release build whose certificate
  SHA-256 does not match the recorded production fingerprint as a regression
  and do not publish it.
- The Task 10.5 source-availability gate is not satisfied: the exact
  Dropweb app source commit and source archive for this build are not yet
  reachable from `dropweb.org`, or the served cabinet source URL is missing
  when the APK depends on the served zencab cabinet.
- APK SHA-256 or signing certificate SHA-256 has not been computed from the
  exact published `.apk` file.
- Keystore lives only on one machine with no offline backup.

## Build wrapper

`tool/release/build_direct_apk.sh` is a thin wrapper that runs
`dart run setup.dart android --arch arm64`. It expects the local signing
configuration (`android/app/keystore.jks` + `storePassword` / `keyAlias` /
`keyPassword` in `android/local.properties`) to already be present locally and
**NOT** committed. The wrapper does not provision signing — that is an
operator step. If the production signing config is missing, the underlying
Gradle release tasks will abort with an explicit message naming the required
inputs (see "Keystore and secret hygiene" above).
