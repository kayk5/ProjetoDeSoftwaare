import org.gradle.api.initialization.resolve.RepositoriesMode
import java.util.Properties
import java.io.FileInputStream

// Define o modo como os repositórios são gerenciados
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

// Bloco mais importante: Diz onde encontrar os PLUGINS
pluginManagement {
    val localProperties = Properties()
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { stream ->
            localProperties.load(stream)
        }
    }

    val flutterSdkPath = localProperties.getProperty("flutter.sdk")
    require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }

    repositories {
        google()
        mavenCentral()
        // Adiciona o repositório local do Flutter SDK
        maven {
            url = uri("$flutterSdkPath/packages/flutter_tools/gradle")
        }
    }
}

rootProject.name = "android"
include(":app")