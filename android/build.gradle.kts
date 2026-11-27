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
}

// Some Flutter plugins (notably Agora) set their own compile SDK during
// project evaluation. Apply the SDK override after their build scripts run,
// so their AAR metadata checks use API 36 rather than the plugin's old API.
subprojects {
    plugins.withId("com.android.library") {
        afterEvaluate {
            extensions.findByType(
                com.android.build.api.dsl.LibraryExtension::class.java
            )?.compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}