plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.jiesheng.folio"
    compileSdk = 35

    /**
     * 正式包的签名。
     *
     * keystore 跟着仓库走（这是个纯本地、无账号的个人 App，不是为了上架商店），
     * 好处是 CI 和本地打出来的包签名一致，装过一次就能一直覆盖升级。
     * 如果要上架商店，请换成自己的密钥并把口令挪到 CI secrets。
     */
    signingConfigs {
        create("release") {
            storeFile = file("keystore/folio-release.jks") // app/keystore/
            storePassword = "folio-jiesheng-2026"
            keyAlias = "folio"
            keyPassword = "folio-jiesheng-2026"
        }
    }

    defaultConfig {
        applicationId = "com.jiesheng.folio"
        minSdk = 26
        targetSdk = 35
        versionCode = 1000003
        versionName = "1.1.2"
        vectorDrawables.useSupportLibrary = true
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
        }
        release {
            // 只用资源压缩，不做代码混淆：混淆会让崩溃栈难读，收益对这个体量的 App 很小
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    applicationVariants.all {
        outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output.outputFileName = "folio-${versionName}-${name}.apk"
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
        buildConfig = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")

    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")

    testImplementation("junit:junit:4.13.2")
}
