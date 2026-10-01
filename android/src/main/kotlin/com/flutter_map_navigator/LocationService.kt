package com.flutter_map_navigator

import android.content.Context
import android.location.Location
import android.os.Build
import android.os.Looper
import com.google.android.gms.location.*

class LocationService(private val context: Context) {

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    fun getCurrentLocation(onSuccess: (Map<String, Any?>) -> Unit, onError: (String) -> Unit) {
        try {
            fusedLocationClient.lastLocation
                .addOnSuccessListener { location: Location? ->
                    if (location != null) {
                        onSuccess(locationToMap(location))
                    } else {
                        requestSingleUpdate(onSuccess, onError)
                    }
                }
                .addOnFailureListener { exception ->
                    onError(exception.message ?: "Failed to get current location")
                }
        } catch (e: SecurityException) {
            onError("Location permission not granted: ${e.message}")
        }
    }

    private fun requestSingleUpdate(onSuccess: (Map<String, Any?>) -> Unit, onError: (String) -> Unit) {
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            1000L
        ).setMaxUpdates(1).build()

        val callback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                val location = locationResult.lastLocation
                if (location != null) {
                    onSuccess(locationToMap(location))
                } else {
                    onError("Location unavailable")
                }
                fusedLocationClient.removeLocationUpdates(this)
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(locationRequest, callback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            onError("Location permission required: ${e.message}")
        }
    }

    companion object {
        fun locationToMap(location: Location): Map<String, Any?> {
            return hashMapOf(
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "accuracy" to location.accuracy.toDouble(),
                "altitude" to location.altitude,
                "speed" to location.speed.toDouble(),
                "heading" to location.bearing.toDouble(),
                "timestamp" to location.time,
                "isMock" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) location.isMock else false
            )
        }
    }
}
