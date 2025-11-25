plugins {
    id("com.android.application") version "8.1.1" apply false
    id("org.jetbrains.kotlin.android") version "1.8.10" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.crashlytics") version "2.9.7" apply false
}

buildscript {
    repositories {
        google()
        mavenCentral()
        maven(url = uri("https://storage.googleapis.com/download.flutter.io"))
    }
    dependencies {
        // Add the Flutter Gradle plugin to the buildscript classpath so it can be resolved from the Flutter repo.
        classpath("dev.flutter:flutter-gradle-plugin:1.0.3")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}