package com.flutter_map_navigator

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*

class TrackingForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "flutter_map_navigator_foreground_channel"
        const val NOTIFICATION_ID = 8801
        const val ACTION_START = "ACTION_START_TRACKING"
        const val ACTION_STOP = "ACTION_STOP_TRACKING"
        const val ACTION_UPDATE_NOTIFICATION = "ACTION_UPDATE_NOTIFICATION"

        var isRunning = false
            private set

        var locationListener: ((Map<String, Any?>) -> Unit)? = null
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                for (location in locationResult.locations) {
                    val locationMap = hashMapOf<String, Any?>(
                        "latitude" to location.latitude,
                        "longitude" to location.longitude,
                        "accuracy" to location.accuracy.toDouble(),
                        "altitude" to location.altitude,
                        "speed" to location.speed.toDouble(),
                        "heading" to location.bearing.toDouble(),
                        "timestamp" to location.time,
                        "isMock" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) location.isMock else false
                    )
                    locationListener?.invoke(locationMap)
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val title = intent.getStringExtra("title") ?: "Navigation Active"
                val text = intent.getStringExtra("text") ?: "Tracking location in background"
                startForeground(NOTIFICATION_ID, buildNotification(title, text))
                startLocationUpdates()
                isRunning = true
            }
            ACTION_UPDATE_NOTIFICATION -> {
                val title = intent.getStringExtra("title") ?: "Navigation Active"
                val text = intent.getStringExtra("text") ?: "Tracking location in background"
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.notify(NOTIFICATION_ID, buildNotification(title, text))
            }
            ACTION_STOP -> {
                stopLocationUpdates()
                isRunning = false
                stopForeground(true)
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun startLocationUpdates() {
        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            2000L
        ).setMinUpdateIntervalMillis(1000L)
            .setMinUpdateDistanceMeters(0f)
            .build()

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun stopLocationUpdates() {
        fusedLocationClient.removeLocationUpdates(locationCallback)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Navigation Background Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Used for continuous GPS navigation and tracking"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(title: String, text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopLocationUpdates()
        isRunning = false
        super.onDestroy()
    }
}
