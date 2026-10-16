package dev.sudoguy.uniro

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val CHANNEL = "dev.sudoguy.uniro/widget"
    private val DEVICE = "dev.sudoguy.uniro/device"
    private val REQ_STORAGE = 4101
    private var storageResult: MethodChannel.Result? = null

    private fun flags(): SharedPreferences =
        getSharedPreferences("uniro1_flags", Context.MODE_PRIVATE)

    private fun storagePermission(): String =
        if (Build.VERSION.SDK_INT >= 33)
            android.Manifest.permission.READ_MEDIA_IMAGES
        else
            android.Manifest.permission.READ_EXTERNAL_STORAGE

    private fun storageStatus(): String {
        try {
            if (checkSelfPermission(storagePermission()) ==
                PackageManager.PERMISSION_GRANTED
            ) return "granted"
            if (!flags().getBoolean("asked_storage", false)) return "denied"
            return if (shouldShowRequestPermissionRationale(
                    storagePermission()
                )
            ) "denied" else "permanentlyDenied"
        } catch (_: Throwable) {
            return "unknown"
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                if (call.method == "updateWidget") {
                    CampusWidgetProvider.updateAllWidgets(applicationContext)
                    CampusMonthWidgetProvider.updateAllWidgets(applicationContext)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            } catch (e: Throwable) {
                e.printStackTrace()
                try {
                    result.error("WIDGET_ERROR", e.message, null)
                } catch (_: Throwable) {
                    // Result already replied; nothing left to do.
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getTimeZoneId" -> {
                        result.success(TimeZone.getDefault().id)
                    }
                    "getNeedsReschedule" -> {
                        val sp = applicationContext.getSharedPreferences(
                            "FlutterSharedPreferences",
                            Context.MODE_PRIVATE
                        )
                        result.success(sp.getBoolean("ct_needs_reschedule", false))
                    }
                    "clearNeedsReschedule" -> {
                        applicationContext.getSharedPreferences(
                            "FlutterSharedPreferences",
                            Context.MODE_PRIVATE
                        ).edit().putBoolean("ct_needs_reschedule", false).apply()
                        result.success(true)
                    }
                    "getDeviceInfo" -> {
                        result.success(mapOf(
                            "apiLevel" to Build.VERSION.SDK_INT,
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL
                        ))
                    }
                    "areNotificationsEnabled" -> {
                        try {
                            val nm = getSystemService(
                                Context.NOTIFICATION_SERVICE
                            ) as android.app.NotificationManager
                            result.success(nm.areNotificationsEnabled())
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                    "canScheduleExactAlarms" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= 31) {
                                val am = getSystemService(
                                    Context.ALARM_SERVICE
                                ) as android.app.AlarmManager
                                result.success(am.canScheduleExactAlarms())
                            } else {
                                result.success(true)
                            }
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        try {
                            val pm = getSystemService(
                                Context.POWER_SERVICE
                            ) as PowerManager
                            result.success(
                                pm.isIgnoringBatteryOptimizations(packageName)
                            )
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            startActivity(Intent(
                                Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                            ))
                            result.success(true)
                        } catch (_: Throwable) {
                            try {
                                startActivity(Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName")
                                ))
                                result.success(true)
                            } catch (e2: Throwable) {
                                e2.printStackTrace()
                                result.error(
                                    "DEVICE_ERROR", e2.message, null
                                )
                            }
                        }
                    }
                    "openAppSettings" -> {
                        try {
                            startActivity(Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            ))
                            result.success(true)
                        } catch (e: Throwable) {
                            e.printStackTrace()
                            result.error("DEVICE_ERROR", e.message, null)
                        }
                    }
                    "hasVibrator" -> {
                        // Legacy VIBRATOR_SERVICE on purpose: hasVibrator()
                        // exists since API 11 and works on every version
                        // without VibratorManager branching (API 31+).
                        try {
                            @Suppress("DEPRECATION")
                            val vib = getSystemService(
                                Context.VIBRATOR_SERVICE
                            ) as android.os.Vibrator
                            result.success(vib.hasVibrator())
                        } catch (_: Throwable) {
                            result.success(false)
                        }
                    }
                    "isTouchHapticsEnabled" -> {
                        // System "Touch feedback" toggle. Readable without
                        // any permission; defaults to on when the key is
                        // absent (fresh devices / managed profiles).
                        try {
                            val v = Settings.System.getInt(
                                contentResolver,
                                Settings.System.HAPTIC_FEEDBACK_ENABLED,
                                1
                            )
                            result.success(v != 0)
                        } catch (_: Throwable) {
                            result.success(true)
                        }
                    }
                    "supportsSelectionTick" -> {
                        // True when the motor can play the predefined tick
                        // behind Flutter's selectionClick (unsupported on
                        // some Realme/ColorOS HALs, where it stays silent).
                        // areEffectsSupported needs API 29+; older devices
                        // keep the designed feel. Fail-open (true) so
                        // unknown means unchanged.
                        try {
                            if (Build.VERSION.SDK_INT >= 29) {
                                @Suppress("DEPRECATION")
                                val vib = getSystemService(
                                    Context.VIBRATOR_SERVICE
                                ) as android.os.Vibrator
                                result.success(vib.areAllEffectsSupported(
                                    android.os.VibrationEffect.EFFECT_TICK
                                ))
                            } else {
                                result.success(true)
                            }
                        } catch (_: Throwable) {
                            result.success(true)
                        }
                    }
                    "openInstallPermissionSettings" -> {
                        try {
                            startActivity(Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            ))
                            result.success(true)
                        } catch (e: Throwable) {
                            e.printStackTrace()
                            try {
                                result.error(
                                    "DEVICE_ERROR", e.message, null
                                )
                            } catch (_: Throwable) {
                            }
                        }
                    }
                    "getStoragePermissionStatus" -> {
                        result.success(storageStatus())
                    }                    "requestStoragePermission" -> {
                        val st = storageStatus()
                        if (st == "granted" || st == "permanentlyDenied") {
                            result.success(st)
                        } else {
                            flags().edit()
                                .putBoolean("asked_storage", true).apply()
                            try {
                                storageResult?.let {
                                    try {
                                        it.error("CANCELLED", null, null)
                                    } catch (_: Throwable) {
                                    }
                                }
                            } catch (_: Throwable) {
                            }
                            storageResult = result
                            try {
                                requestPermissions(
                                    arrayOf(storagePermission()), REQ_STORAGE
                                )
                            } catch (e: Throwable) {
                                e.printStackTrace()
                                storageResult = null
                                try {
                                    result.error(
                                        "DEVICE_ERROR", e.message, null
                                    )
                                } catch (_: Throwable) {
                                }
                            }
                        }
                    }
                    "getCacheDir" -> {
                        result.success(cacheDir.absolutePath)
                    }
                    "verifyApk" -> {
                        // Reads a downloaded APK's identity without
                        // installing it: package name, versionCode, and
                        // whether its signing cert matches ours.
                        try {
                            val path =
                                call.argument<String>("path")
                            val expected =
                                call.argument<String>("expectedPackage") ?: ""
                            val minCode =
                                (call.argument<Number>("minVersionCode")
                                    ?: 0).toLong()
                            if (path.isNullOrEmpty()) {
                                result.error("ARG", "missing path", null)
                            } else {
                                @Suppress("DEPRECATION")
                                val archive = packageManager
                                    .getPackageArchiveInfo(
                                        path,
                                        PackageManager.GET_SIGNATURES or
                                            PackageManager
                                                .GET_SIGNING_CERTIFICATES
                                    )
                                if (archive == null) {
                                    result.error(
                                        "PARSE", "not a valid APK", null
                                    )
                                } else {
                                    val code = if (Build.VERSION.SDK_INT >= 28)
                                        archive.longVersionCode
                                    else
                                        archive.versionCode.toLong()
                                    result.success(mapOf(
                                        "packageName" to
                                            (archive.packageName ?: ""),
                                        "versionCode" to code,
                                        "packageOk" to
                                            (archive.packageName == expected),
                                        "upgradeOk" to (code >= minCode),
                                        "signatureOk" to
                                            archiveSignaturesMatch(archive)
                                    ))
                                }
                            }
                        } catch (e: Throwable) {
                            e.printStackTrace()
                            try {
                                result.error("VERIFY", e.message, null)
                            } catch (_: Throwable) {
                            }
                        }
                    }
                    "installApk" -> {
                        // Hands a verified APK to Android's package
                        // installer. The user always confirms — silent
                        // installs are impossible for this app.
                        try {
                            val path = call.argument<String>("path")
                            val file = if (path.isNullOrEmpty()) null
                            else java.io.File(path)
                            if (file == null || !file.isFile) {
                                result.error(
                                    "ARG", "downloaded file missing", null
                                )
                            } else if (Build.VERSION.SDK_INT >= 26 &&
                                !packageManager.canRequestPackageInstalls()
                            ) {
                                startActivity(Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ))
                                result.success("needPermission")
                            } else {
                                val uri = androidx.core.content.FileProvider
                                    .getUriForFile(
                                        this,
                                        "$packageName.fileprovider",
                                        file
                                    )
                                val intent = Intent(Intent.ACTION_VIEW)
                                    .setDataAndType(
                                        uri,
                                        "application/vnd.android.package-archive"
                                    )
                                    .addFlags(
                                        Intent.FLAG_ACTIVITY_NEW_TASK
                                    )
                                    .addFlags(
                                        Intent.FLAG_GRANT_READ_URI_PERMISSION
                                    )
                                startActivity(intent)
                                result.success("launched")
                            }
                        } catch (e: Throwable) {
                            e.printStackTrace()
                            try {
                                result.error(
                                    "INSTALL", e.message, null
                                )
                            } catch (_: Throwable) {
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Throwable) {
                e.printStackTrace()
                try {
                    result.error("DEVICE_ERROR", e.message, null)
                } catch (_: Throwable) {
                    // Result already replied; nothing left to do.
                }
            }
        }
    }

    private fun archiveSignaturesMatch(
        archive: android.content.pm.PackageInfo
    ): Boolean {
        try {
            val current = if (Build.VERSION.SDK_INT >= 28) {
                @Suppress("DEPRECATION")
                val ci = packageManager.getPackageInfo(
                    packageName, PackageManager.GET_SIGNING_CERTIFICATES
                )
                val si = ci.signingInfo ?: return false
                val arr = if (si.hasMultipleSigners())
                    si.apkContentsSigners
                else
                    si.signingCertificateHistory
                arr?.map { sha256hex(it.toByteArray()) }?.toSet()
                    ?: return false
            } else {
                @Suppress("DEPRECATION")
                val ci = packageManager.getPackageInfo(
                    packageName, PackageManager.GET_SIGNATURES
                )
                @Suppress("DEPRECATION")
                ci.signatures?.map { sha256hex(it.toByteArray()) }?.toSet()
                    ?: return false
            }
            if (current.isEmpty()) return false
            val archived = if (Build.VERSION.SDK_INT >= 28) {
                val si = archive.signingInfo
                if (si == null) {
                    @Suppress("DEPRECATION")
                    archive.signatures?.map {
                        sha256hex(it.toByteArray())
                    }?.toSet() ?: return false
                } else {
                    val arr = if (si.hasMultipleSigners())
                        si.apkContentsSigners
                    else
                        si.signingCertificateHistory
                    arr?.map { sha256hex(it.toByteArray()) }?.toSet()
                        ?: return false
                }
            } else {
                @Suppress("DEPRECATION")
                archive.signatures?.map {
                    sha256hex(it.toByteArray())
                }?.toSet() ?: return false
            }
            return archived.isNotEmpty() && archived == current
        } catch (_: Throwable) {
            return false
        }
    }

    private fun sha256hex(bytes: ByteArray): String {
        val md = java.security.MessageDigest.getInstance("SHA-256")
        return md.digest(bytes).joinToString("") { "%02x".format(it) }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(
            requestCode, permissions, grantResults
        )
        if (requestCode == REQ_STORAGE) {
            val r = storageResult
            storageResult = null
            try {
                r?.success(storageStatus())
            } catch (_: Throwable) {
            }
        }
    }

    override fun onResume() {
        super.onResume()
        CampusWidgetProvider.updateAllWidgets(applicationContext)
        CampusMonthWidgetProvider.updateAllWidgets(applicationContext)
    }
}
