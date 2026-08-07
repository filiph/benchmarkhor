allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    project.configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.test" && requested.name == "runner") {
                useVersion("1.5.2")
            }
            if (requested.group == "androidx.test" && requested.name == "rules") {
                useVersion("1.5.0")
            }
            if (requested.group == "androidx.test" && requested.name == "monitor") {
                useVersion("1.6.1")
            }
            if (requested.group == "androidx.test.core") {
                useVersion("1.5.0")
            }
            if (requested.group == "androidx.test.ext" && requested.name == "junit") {
                useVersion("1.1.5")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
