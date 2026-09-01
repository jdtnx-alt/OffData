allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val shortPath = "C:/Users/JUANDA~1/OneDrive/Documents/GitHub/offdata/build"
val rootBuildDir = if (file("C:/Users/JUANDA~1").exists()) {
    file(shortPath)
} else {
    file("${rootProject.projectDir}/../build")
}
rootProject.layout.buildDirectory.set(rootBuildDir)

subprojects {
    project.layout.buildDirectory.set(File(rootBuildDir, project.name))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
