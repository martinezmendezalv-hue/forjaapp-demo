package es.forja.forja_app_demo

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val carpeta get() = File(cacheDir, "actualizaciones").apply { mkdirs() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "forja/actualizacion").setMethodCallHandler { llamada, resultado ->
            when (llamada.method) {
                // Dónde guardar el APK descargado.
                "carpeta" -> resultado.success(carpeta.absolutePath)
                // Abre el instalador de Android con el APK descargado.
                "instalar" -> {
                    val apk = File(llamada.argument<String>("ruta") ?: "")
                    // Solo se instala lo que está en nuestra carpeta de actualizaciones.
                    if (!apk.canonicalPath.startsWith(carpeta.canonicalPath + File.separator) || !apk.isFile) {
                        resultado.error("ruta", "Ruta no válida", null)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                        // La primera vez Android pide permitir instalar apps desde ForjaApp.
                        startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                        resultado.success("permiso")
                    } else {
                        val uri = FileProvider.getUriForFile(this, "$packageName.actualizaciones", apk)
                        startActivity(
                            Intent(Intent.ACTION_VIEW)
                                .setDataAndType(uri, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        resultado.success("instalando")
                    }
                }
                else -> resultado.notImplemented()
            }
        }
    }
}
