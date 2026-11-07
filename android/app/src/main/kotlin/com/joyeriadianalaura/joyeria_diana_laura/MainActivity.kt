package com.joyeriadianalaura.joyeria_diana_laura

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Detección de root (#99): la app la consulta al abrir con el canal joyeria/dispositivo.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "joyeria/dispositivo").setMethodCallHandler { llamada, resultado ->
            if (llamada.method == "tieneRoot") resultado.success(tieneRoot()) else resultado.notImplemented()
        }
    }

    // Señales comunes de root: el programa su en las rutas del sistema, una compilación firmada con
    // llaves de prueba o de depuración (userdebug/eng, que permiten adb root) o una app de root
    // instalada (Magisk, SuperSU).
    private fun tieneRoot(): Boolean {
        val rutasSu = listOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/system/sd/xbin/su",
            "/system/bin/failsafe/su", "/data/local/su", "/data/local/bin/su", "/data/local/xbin/su", "/su/bin/su",
        )
        if (rutasSu.any { File(it).exists() }) return true
        if (Build.TAGS?.contains("test-keys") == true) return true
        if (Build.TYPE == "userdebug" || Build.TYPE == "eng") return true
        val appsDeRoot = listOf("com.topjohnwu.magisk", "eu.chainfire.supersu", "com.koushikdutta.superuser", "com.noshufou.android.su")
        return appsDeRoot.any {
            try {
                packageManager.getPackageInfo(it, 0)
                true
            } catch (e: Exception) {
                false
            }
        }
    }
}
