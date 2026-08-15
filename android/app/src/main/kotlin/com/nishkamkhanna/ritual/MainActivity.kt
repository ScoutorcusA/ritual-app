package com.nishkamkhanna.ritual

import android.location.Address
import android.location.Geocoder
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val geocoderExecutor = Executors.newSingleThreadExecutor()

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
        geocoderExecutor.shutdownNow()
        super.onDestroy()
    }
}
