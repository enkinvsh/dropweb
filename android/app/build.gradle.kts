import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localPropertiesFile = rootProject.file("local.properties")
val localProperties = Properties().apply {
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { load(it) }
    }
}

val mStoreFile: File = file("keystore.jks")
val mStorePassword: String? = localProperties.getProperty("storePassword")
val mKeyAlias: String? = localProperties.getProperty("keyAlias")
val mKeyPassword: String? = localProperties.getProperty("keyPassword")

// Release signing is considered configured only when:
//   - keystore.jks is an actual regular file (a directory or symlink-to-dir
//     of the same name must NOT count as a valid keystore), AND
//   - every credential property is present AND non-blank after trimming
//     (an empty or whitespace-only value in local.properties must NOT count
//     as configured — apksigner would later reject it anyway, and we want
//     the failure surfaced up-front by the task-graph guard with the same
//     actionable message instead of mid-build with a cryptic apksigner
//     error).
fun String?.isPresentNonBlank(): Boolean = !this.isNullOrBlank()

val isRelease = mStoreFile.isFile
        && mStorePassword.isPresentNonBlank()
        && mKeyAlias.isPresentNonBlank()
        && mKeyPassword.isPresentNonBlank()

android {
    namespace = "app.dropweb"
    compileSdk = 36
    ndkVersion = "28.0.13004108"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "app.dropweb"
        // hardcoded — flutter_secure_storage 10.x requires minSdk=24 (Android 7.0+),
        // and the core module already required ≥23. Bumped from 23 to 24 together
        // with the secure-storage migration in 2712935. Older Flutter SDKs in CI
        // default to 21; leaving this as `flutter.minSdkVersion` is NOT safe here.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (isRelease) {
            create("release") {
                storeFile = mStoreFile
                storePassword = mStorePassword
                keyAlias = mKeyAlias
                keyPassword = mKeyPassword
            }
        }
    }

    packaging {
        jniLibs {
            // Extract bundled .so files onto disk rather than loading them
            // straight from the APK zip. Keeps compatibility with native
            // libraries that expect a real on-disk path.
            //
            // 16KB page alignment (required by Google Play for Android 15+)
            // is preserved by building each .so with `-Wl,-z,max-page-size=16384`
            // at the NDK/Go level, not by this packaging flag. The mihomo/clash
            // core libs already ship aligned.
            useLegacyPackaging = true
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = false

            // Fail-closed signing: only attach the production signing config when
            // every required input is present (keystore + storePassword + keyAlias
            // + keyPassword). When inputs are missing, signingConfig is left null
            // so AGP cannot silently sign the release variant with the debug key.
            // The task-graph guard below aborts any release packaging task before
            // it runs, with an actionable message naming the required (non-secret)
            // inputs. Release builds without a production keystore MUST NOT ship.
            if (isRelease) {
                signingConfig = signingConfigs.getByName("release")
            }

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

// Fail-closed release signing guard.
//
// AGP would otherwise allow a release variant with no signingConfig to either
// (a) silently fall back to the debug signing key (the previous behavior here),
// or (b) produce an unsigned artifact that fails much later in the pipeline
// with a non-obvious error. Neither is acceptable for a Play Store / direct-APK
// release: any artifact must be signed by the production key or the build must
// abort before any APK/AAB bytes are written.
//
// This guard scans the resolved task graph and aborts release packaging tasks
// up-front, with a message that names the required non-secret inputs so the
// operator can self-correct without leaking credentials into logs.
//
// Non-release tasks (debug build, install, test, lint, analyze, IDE sync,
// `tasks`, `help`) are NOT affected — they continue to work without any
// production keystore present.
val releaseEntryPoints = setOf(
    "assembleRelease",
    "bundleRelease",
    "installRelease",
    "packageRelease",
    "packageReleaseBundle",
    "signReleaseApk",
    "signReleaseBundle",
)

gradle.taskGraph.whenReady {
    if (isRelease) {
        return@whenReady
    }
    val scheduled = allTasks.filter { task ->
        task.path.startsWith(":app:") && task.name in releaseEntryPoints
    }
    if (scheduled.isEmpty()) {
        return@whenReady
    }
    val scheduledPaths = scheduled.joinToString(", ") { it.path }
    throw GradleException(
        """
        Release signing configuration is missing. Refusing to run: $scheduledPaths

        Release builds MUST be signed with the production keystore. Falling
        back to the debug key is disabled. To unblock a real release build,
        provision the following locally (do NOT commit any of these values
        or files):

          1. Production keystore at: android/app/keystore.jks
          2. In android/local.properties, set:
               storePassword=<your store password>
               keyAlias=<your key alias>
               keyPassword=<your key password>

        See docs/release/direct-apk.md for the full production signing and
        backup checklist. If you only need a debug build, run the matching
        debug task (e.g. :app:assembleDebug) — debug builds do not require
        the production keystore.
        """.trimIndent()
    )
}

flutter {
    source = "../.."
}

// Force androidx.datastore 1.1.7 — 1.2.0 ships a libdatastore_shared_counter.so
// that is NOT 16KB-aligned and causes Google Play rejection.
// See: https://github.com/flutter/flutter/issues/182898
// TODO: remove once datastore 1.3.0 (with proper 16KB alignment) is stable.
configurations.all {
    resolutionStrategy {
        force("androidx.datastore:datastore:1.1.7")
        force("androidx.datastore:datastore-android:1.1.7")
        force("androidx.datastore:datastore-preferences:1.1.7")
        force("androidx.datastore:datastore-preferences-android:1.1.7")
    }
}

dependencies {
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.aar"))))
    implementation(project(":core"))
    implementation("androidx.core:core-splashscreen:1.0.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.code.gson:gson:2.10.1")
    implementation("com.android.tools.smali:smali-dexlib2:3.0.9") {
        exclude(group = "com.google.guava", module = "guava")
    }
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
