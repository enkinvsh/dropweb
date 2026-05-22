#!/usr/bin/env bash
# Direct APK build wrapper for Dropweb (ARM64-only).
#
# Preconditions (operator responsibility, NOT performed by this script):
#   - Production keystore present locally at `android/app/keystore.jks`, with
#     matching `storePassword` / `keyAlias` / `keyPassword` entries in
#     `android/local.properties`. These files MUST exist locally and MUST NOT
#     be committed.
#   - `android/local.properties` (Android SDK / NDK paths) is configured.
#   - The Task 10.5 source-availability gate is ready (see
#     `docs/release/source-availability.md`).
#
# Release signing is fail-closed: if the production keystore or its credentials
# in `android/local.properties` are missing, the underlying Gradle release
# tasks (`:app:assembleRelease`, `:app:bundleRelease`, ...) abort up-front with
# an explicit message. There is no debug-key fallback. See
# `docs/release/direct-apk.md` for the hard gates.

set -euo pipefail

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"

# Resolve script directory and run from the repo root so relative paths in
# setup.dart (e.g. `android/`, `core/`) resolve correctly regardless of where
# the operator invokes the wrapper from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

dart run setup.dart android --arch arm64
