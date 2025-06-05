plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.social_log_in"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" // or use flutter.ndkVersion if preferred
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.social_log_in"
        minSdk = 21 // Added to fix NDK compatibility issue
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug") // Replace with proper release signing config for production
        }
    }
}

flutter {
    source = "../.."
}