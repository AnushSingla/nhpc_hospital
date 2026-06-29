allprojects {
    repositories {
        // Ensure Google's Maven repository is available for Android build tools
        google()
        maven {
            url = uri("https://dl.google.com/dl/android/maven2/")
        }
        mavenCentral()
        // Common extra repositories
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
