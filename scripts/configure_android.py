from pathlib import Path

Path('android/app/build.gradle.kts').write_text('''plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}
val signingPath = System.getenv("ANDROID_KEYSTORE_PATH")
android {
    namespace = "vn.bannie.nhac_viec"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_17.toString() }
    defaultConfig {
        applicationId = "vn.bannie.nhac_viec"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (signingPath != null) {
            create("personal") {
                storeFile = file(signingPath)
                storePassword = System.getenv("ANDROID_STORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        release {
            if (signingPath != null) signingConfig = signingConfigs.getByName("personal")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}
flutter { source = "../.." }
dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }
''')

Path('android/app/src/main/AndroidManifest.xml').write_text('''<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
    <application android:label="Nhắc việc" android:name="${applicationName}" android:icon="@mipmap/ic_launcher" android:allowBackup="false">
        <activity android:name=".MainActivity" android:showWhenLocked="true" android:turnScreenOn="true" android:exported="true" android:launchMode="singleTop" android:taskAffinity="" android:theme="@style/LaunchTheme" android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode" android:hardwareAccelerated="true" android:windowSoftInputMode="adjustResize">
            <meta-data android:name="io.flutter.embedding.android.NormalTheme" android:resource="@style/NormalTheme"/>
            <intent-filter><action android:name="android.intent.action.MAIN"/><category android:name="android.intent.category.LAUNCHER"/></intent-filter>
        </activity>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/><action android:name="android.intent.action.MY_PACKAGE_REPLACED"/><action android:name="android.intent.action.QUICKBOOT_POWERON"/><action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/></intent-filter>
        </receiver>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver"/>
        <meta-data android:name="flutterEmbedding" android:value="2"/>
    </application>
    <queries><intent><action android:name="android.speech.RecognitionService"/></intent></queries>
</manifest>
''')

drawable=Path('android/app/src/main/res/drawable')
drawable.mkdir(parents=True,exist_ok=True)
(drawable/'ic_stat_reminder.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24"><path android:fillColor="#FFFFFFFF" android:pathData="M12,2A10,10 0,1 0,12 22A10,10 0,0 0,12 2M11,6h2v6l4,2l-1,2l-5,-3z"/></vector>''')
# App icon is a clock, not Flutter's default logo. Android accepts a vector resource.
for folder in ('mipmap-hdpi','mipmap-mdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi'):
    p=Path('android/app/src/main/res')/folder/'ic_launcher.png'
    p.unlink(missing_ok=True)
icons=Path('android/app/src/main/res/mipmap-anydpi')
icons.mkdir(parents=True,exist_ok=True)
(icons/'ic_launcher.xml').write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="48dp" android:height="48dp" android:viewportWidth="48" android:viewportHeight="48"><path android:fillColor="#623B67" android:pathData="M0,0h48v48h-48z"/><path android:fillColor="#FFF1D6" android:pathData="M24,7a17,17 0,1 0,0 34a17,17 0,1 0,0 -34"/><path android:strokeColor="#623B67" android:strokeWidth="3" android:strokeLineCap="round" android:pathData="M24,14v11l8,5"/></vector>''')
