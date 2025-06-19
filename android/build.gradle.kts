import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension
import org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    
    // Use JVM Toolchain to ensure consistent Java and Kotlin JVM targets.
    // This will configure Kotlin's jvmTarget and Java's source/targetCompatibility.
    // It applies to projects that have the respective Kotlin plugins.
    plugins.withId("org.jetbrains.kotlin.android") {
        project.extensions.getByType<KotlinAndroidProjectExtension>().jvmToolchain(21)
    }
    // For any pure Kotlin/JVM modules (less common in Flutter's android directory structure)
    plugins.withId("org.jetbrains.kotlin.jvm") {
        project.extensions.getByType<KotlinJvmProjectExtension>().jvmToolchain(21)
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
