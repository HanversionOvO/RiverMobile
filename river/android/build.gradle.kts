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

fun Project.fallbackNamespace(): String {
    val sanitizedName =
        name.lowercase()
            .replace(Regex("[^a-z0-9_]"), "_")
            .replace(Regex("^[^a-z]+"), "lib_$0")
    return "cc.river.generated.$sanitizedName"
}

fun Project.manifestPackage(): String? {
    val manifestFile = projectDir.resolve("src/main/AndroidManifest.xml")
    if (!manifestFile.exists()) {
        return null
    }
    val content = manifestFile.readText()
    val match = Regex("""package\s*=\s*"([^"]+)"""").find(content)
    return match?.groupValues?.getOrNull(1)?.takeIf { it.isNotBlank() }
}

fun Project.ensureAndroidNamespace() {
    val androidExt = extensions.findByName("android") ?: return
    val getNamespace =
        androidExt::class.java.methods.firstOrNull {
            it.name == "getNamespace" && it.parameterCount == 0
        } ?: return
    val setNamespace =
        androidExt::class.java.methods.firstOrNull {
            it.name == "setNamespace" &&
                it.parameterCount == 1 &&
                it.parameterTypes[0] == String::class.java
        } ?: return
    val currentNamespace = (getNamespace.invoke(androidExt) as? String).orEmpty()
    if (currentNamespace.isNotBlank()) {
        return
    }
    val resolvedNamespace = manifestPackage() ?: fallbackNamespace()
    setNamespace.invoke(androidExt, resolvedNamespace)
}

subprojects {
    pluginManager.withPlugin("com.android.application") {
        ensureAndroidNamespace()
    }
    pluginManager.withPlugin("com.android.library") {
        ensureAndroidNamespace()
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
