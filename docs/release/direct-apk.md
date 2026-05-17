# Direct APK release

Direct APK builds are signed with the Dropweb production Android keystore and
distributed from `dropweb.org/download` outside Google Play. The build pipeline
must be airtight before any APK URL is published.

## Keystore and secret hygiene

- A **production keystore is required**. Builds that fall back to the debug
  signing key MUST NOT be published.
- **Never commit** any of the following to git, CI logs, screenshots, or chat:
  - `.jks` / `.keystore` files
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

- Build signed with the debug key (signing fell back, keystore missing, or
  `key.properties` not loaded).
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
configuration (`android/app/key.properties` + the keystore referenced by it)
to already be present locally and **NOT** committed. The wrapper does not
provision signing — that is an operator step.
