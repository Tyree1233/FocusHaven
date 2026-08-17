import java.io.File
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val isReleaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else if (isReleaseBuildRequested) {
    throw GradleException(
        "Wear OS release signing requires android/key.properties so the phone and watch use the same key.",
    )
}

fun requiredSigningProperty(name: String): String =
    keystoreProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("Missing required release-signing property '$name'.")

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.focushaven.app.wear"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.focushaven.app"
        minSdk = 30
        targetSdk = 36
        versionCode = 360010001
        versionName = "1.0.0-wear"
    }

    if (keystorePropertiesFile.exists()) {
        signingConfigs {
            create("release") {
                keyAlias = requiredSigningProperty("keyAlias")
                keyPassword = requiredSigningProperty("keyPassword")
                val configuredStoreFile = File(requiredSigningProperty("storeFile"))
                val signingStoreFile =
                    if (configuredStoreFile.isAbsolute) {
                        configuredStoreFile
                    } else {
                        rootProject.file("app").resolve(configuredStoreFile)
                    }
                if (!signingStoreFile.isFile) {
                    throw GradleException(
                        "Release keystore was not found at ${signingStoreFile.absolutePath}.",
                    )
                }
                storeFile = signingStoreFile
                storePassword = requiredSigningProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfigs.findByName("release")?.let { releaseSigningConfig ->
                signingConfig = releaseSigningConfig
            }
        }
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-wearable:20.0.1")
    testImplementation("junit:junit:4.13.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
