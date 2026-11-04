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
        // 加了 Wear OS 版，作为一次功能更新升到 1.2.0
        versionCode = 1002000
        versionName = "1.2.0"
        vectorDrawables.useSupportLibrary = true
    }

    /**
     * 手机版和手表版共用同一个模块：
     * - 逻辑层（domain/、data/、services/）和动效编排（ui/FolioState.kt、theme/Motion）在 src/main，
     *   两边是同一份代码，动画不可能各写一份走出去；
     * - 界面层各写一份：src/phone（原来的四页 + 浮层）和 src/wear（表盘式重排版）。
     */
    flavorDimensions += "device"
    productFlavors {
        create("phone") {
            dimension = "device"
            applicationId = "com.jiesheng.folio"
            versionNameSuffix = ""
        }
        create("wear") {
            dimension = "device"
            applicationId = "com.jiesheng.folio.wear"
            // Wear OS 3 起才有现在的表盘交互模型
            minSdk = 30
            versionNameSuffix = "-wear"
        }
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
            val flavor = flavorName
            val type = buildType.name
            // phone 叫 folio-<版本>-<类型>，wear 加个 -wear 前缀区分。
            // AGP 会把 versionNameSuffix 合进 versionName，这里先去掉，避免文件名重复。
            val prefix = if (flavor == "wear") "folio-wear" else "folio"
            val baseVersion = (versionName ?: "1.1.2").removeSuffix("-wear")
            output.outputFileName = "$prefix-$baseVersion-$type.apk"
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

    // 手表那套组件只在 wear flavor 里编进来，手机包不会变大
    "wearImplementation"("androidx.wear.compose:compose-material3:1.5.6")
    "wearImplementation"("androidx.wear.compose:compose-foundation:1.5.6")
    "wearImplementation"("androidx.wear:wear:1.3.0")

    testImplementation("junit:junit:4.13.2")
}
