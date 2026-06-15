plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.luanlourenco.sentinela"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.luanlourenco.sentinela"
        minSdk = 30
        targetSdk = 34
        versionCode = 2
        versionName = "1.1"
    }

    // Assinatura: usa keystore privado se os segredos existirem (CI); senão, chave de debug.
    // O release continua NÃO-depurável (blindagem principal contra adb run-as).
    val ksFile = System.getenv("KEYSTORE_FILE")
    signingConfigs {
        create("release") {
            if (ksFile != null) {
                storeFile = file(ksFile)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // R8/ofuscação DESLIGADO de propósito: lição da Faxina — ligar minify sem
            // poder testar runtime aqui mascara crashes. Ativar só após estável no aparelho.
            isMinifyEnabled = false
            isShrinkResources = false
            isDebuggable = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = if (ksFile != null)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")

    // Testes unitarios JVM (rodam sem emulador via :app:testDebugUnitTest)
    testImplementation("junit:junit:4.13.2")
}
