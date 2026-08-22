allprojects {
    repositories {
        google()
        mavenCentral()
        // RootEncoder (v0.7 Checkpoint 2) is distributed via JitPack, not
        // Maven Central -- see https://github.com/pedroSG94/rootencoder/wiki/Add-library-to-your-project
        maven { url = uri("https://jitpack.io") }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
