package com.nishkamkhanna.ritual

import android.app.Activity
import android.content.Intent
import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.File
import java.io.FileInputStream
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val geocoderExecutor = Executors.newSingleThreadExecutor()
    private val fileExecutor = Executors.newSingleThreadExecutor()
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveSource: String? = null

    companion object {
        private const val SAVE_FILE_REQUEST = 48117
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nishkamkhanna.ritual/privacy",
        ).setMethodCallHandler { call, result ->
            if (call.method != "setAppLockEnabled") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val enabled = call.arguments as? Boolean ?: false
            if (enabled) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
            result.success(null)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nishkamkhanna.ritual/city_geocoder",
        ).setMethodCallHandler { call, result ->
            if (call.method != "reverseGeocodeCity") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val latitude = call.argument<Double>("latitude")
            val longitude = call.argument<Double>("longitude")
            if (latitude == null || longitude == null ||
                latitude !in -90.0..90.0 || longitude !in -180.0..180.0
            ) {
                result.error("invalid_coordinates", "The location coordinates were invalid.", null)
                return@setMethodCallHandler
            }
            reverseGeocodeCity(latitude, longitude, result)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.nishkamkhanna.ritual/local_file_saver",
        ).setMethodCallHandler { call, result ->
            if (call.method != "saveFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingSaveResult != null) {
                result.error("save_in_progress", "Another file is already being saved.", null)
                return@setMethodCallHandler
            }
            val sourcePath = call.argument<String>("sourcePath")
            val fileName = call.argument<String>("fileName")
            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
            if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank() || !File(sourcePath).isFile) {
                result.error("invalid_source", "The temporary export file is unavailable.", null)
                return@setMethodCallHandler
            }
            pendingSaveResult = result
            pendingSaveSource = sourcePath
            try {
                startActivityForResult(
                    Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mimeType
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    },
                    SAVE_FILE_REQUEST,
                )
            } catch (error: Exception) {
                pendingSaveResult = null
                pendingSaveSource = null
                result.error("save_unavailable", error.message, null)
            }
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SAVE_FILE_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingSaveResult
        val sourcePath = pendingSaveSource
        pendingSaveResult = null
        pendingSaveSource = null
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null || sourcePath == null) {
            result.success(false)
            return
        }
        val destination = data.data!!
        fileExecutor.execute {
            try {
                FileInputStream(sourcePath).use { input ->
                    contentResolver.openOutputStream(destination, "w").use { output ->
                        if (output == null) throw IOException("Android could not open the destination.")
                        input.copyTo(output, bufferSize = 64 * 1024)
                        output.flush()
                    }
                }
                runOnUiThread { result.success(true) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "save_failed",
                        error.message ?: "Android could not write the export.",
                        null,
                    )
                }
            }
        }
    }

    private fun reverseGeocodeCity(
        latitude: Double,
        longitude: Double,
        result: MethodChannel.Result,
    ) {
        if (!Geocoder.isPresent()) {
            result.error(
                "geocoder_unavailable",
                "This Android device does not have a place-name service.",
                null,
            )
            return
        }

        val geocoder = Geocoder(applicationContext, Locale.getDefault())
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                geocoder.getFromLocation(
                    latitude,
                    longitude,
                    1,
                    object : Geocoder.GeocodeListener {
                        override fun onGeocode(addresses: MutableList<Address>) {
                            runOnUiThread { completeCityResult(addresses.firstOrNull(), result) }
                        }

                        override fun onError(errorMessage: String?) {
                            runOnUiThread {
                                result.error(
                                    "geocoder_failed",
                                    errorMessage?.takeIf { it.isNotBlank() }
                                        ?: "Android could not name this area.",
                                    null,
                                )
                            }
                        }
                    },
                )
            } catch (error: IllegalArgumentException) {
                result.error("geocoder_failed", error.message, null)
            }
            return
        }

        @Suppress("DEPRECATION")
        geocoderExecutor.execute {
            try {
                val address = geocoder.getFromLocation(latitude, longitude, 1)?.firstOrNull()
                runOnUiThread { completeCityResult(address, result) }
            } catch (error: IOException) {
                runOnUiThread {
                    result.error(
                        "geocoder_failed",
                        error.message ?: "Android could not name this area.",
                        null,
                    )
                }
            } catch (error: IllegalArgumentException) {
                runOnUiThread { result.error("geocoder_failed", error.message, null) }
            }
        }
    }

    private fun completeCityResult(address: Address?, result: MethodChannel.Result) {
        if (address == null) {
            result.error("no_city", "Android found no city for this area.", null)
            return
        }
        val city = listOf(
            address.locality,
            address.subAdminArea,
            address.adminArea,
        ).firstOrNull { !it.isNullOrBlank() }?.trim()
        val country = address.countryName?.takeIf { it.isNotBlank() }?.trim()
        val label = listOfNotNull(city, country).distinct().joinToString(", ")
        if (label.isBlank()) {
            result.error("no_city", "Android found no city for this area.", null)
        } else {
            result.success(label)
        }
    }

    override fun onDestroy() {
        pendingSaveResult?.error("activity_closed", "The save was interrupted.", null)
        pendingSaveResult = null
        pendingSaveSource = null
        geocoderExecutor.shutdownNow()
        fileExecutor.shutdownNow()
        super.onDestroy()
    }
}
