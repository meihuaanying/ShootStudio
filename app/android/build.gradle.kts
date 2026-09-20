allprojects {
    repositories {
        // 国内加速镜像优先，失败回退官方源；CI 上设 SS_MAVEN_MIRROR=0 直接走官方源
        // （阿里云镜像偶发 502 会让 Gradle 直接禁用该仓库，导致 CI 误判构建失败）。
        if (System.getenv("SS_MAVEN_MIRROR") != "0") {
            maven("https://maven.aliyun.com/repository/google")
            maven("https://maven.aliyun.com/repository/public")
        }
        google()
        mavenCentral()
    }
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
    // 全局对齐编译目标：部分插件依赖要求 compileSdk ≥ 36，而其自身仍声明旧值。
    // 在子项目 evaluate 完成后通过反射覆盖（兼容 AGP 9 的 DSL 实现）。
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val candidates = listOf(
            Int::class.javaPrimitiveType,
            Integer::class.java,
            String::class.java,
        )
        for (type in candidates) {
            val method = androidExt.javaClass.methods.firstOrNull {
                it.name == "setCompileSdkVersion" && it.parameterTypes.size == 1 && it.parameterTypes[0] == type
            } ?: continue
            try {
                when (type) {
                    Int::class.javaPrimitiveType, Integer::class.java -> method.invoke(androidExt, 36)
                    else -> method.invoke(androidExt, "android-36")
                }
            } catch (_: Throwable) {
                // 忽略：个别插件可能不允许覆盖，保持原值。
            }
            break
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
