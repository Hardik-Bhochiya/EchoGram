plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.neartalk.app.neartalk"
    compileSdk = flutter.compileSdkVersion
    buildToolsVersion = "36.0.0"
    // ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.neartalk.app.neartalk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            ndk {
                debugSymbolLevel = "none"
            }
        }
    }
}

gradle.taskGraph.whenReady {
    tasks.matching {
        it.name.contains("strip", ignoreCase = true) ||
        it.name.contains("extractNativeSymbolTables", ignoreCase = true)
    }.configureEach {
        enabled = false
    }
}

tasks.register("copyNativeLibsForPackaging") {
    doLast {
        val buildDir = layout.buildDirectory.asFile.get()
        for (variant in listOf("debug", "release")) {
            val capitalized = variant.replaceFirstChar { it.uppercase() }
            val mergedDir = File(buildDir, "intermediates/merged_native_libs/$variant/merge${capitalized}NativeLibs/out/lib")
            val strippedDir = File(buildDir, "intermediates/stripped_native_libs/$variant/strip${capitalized}DebugSymbols/out/lib")
            if (mergedDir.exists()) {
                copy {
                    from(mergedDir)
                    into(strippedDir)
                    exclude("**/libVkLayer_khronos_validation.so")
                }
                println("[NativeLibs] Successfully copied native libs for $variant into stripped_native_libs for packaging!")
            }
        }
    }
}

tasks.matching { it.name.startsWith("package", ignoreCase = true) }.configureEach {
    dependsOn("copyNativeLibsForPackaging")
}

flutter {
    source = "../.."
}
