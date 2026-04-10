allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Force older plugins (e.g. isar_flutter_libs which hardcodes
    // compileSdkVersion 30) to compile against a newer SDK so they can find
    // android:attr/lStar (introduced in API 31). Without this, release builds
    // fail with "resource android:attr/lStar not found".
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                if (compileSdk != null && compileSdk!! < 35) {
                    compileSdk = 35
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
