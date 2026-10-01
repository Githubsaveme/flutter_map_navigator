package com.flutter_map_navigator

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class FlutterMapNavigatorPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var methodChannel: MethodChannel
    private lateinit var locationEventChannel: EventChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    private var eventSink: EventChannel.EventSink? = null
    private lateinit var locationService: LocationService

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        locationService = LocationService(context)

        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.flutter_map_navigator/methods")
        methodChannel.setMethodCallHandler(this)

        locationEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "com.flutter_map_navigator/location_stream")
        locationEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                TrackingForegroundService.locationListener = { locationMap ->
                    activity?.runOnUiThread {
                        eventSink?.success(locationMap)
                    }
                }
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                TrackingForegroundService.locationListener = null
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getLocationPermissionStatus" -> {
                result.success(PermissionHelper.checkLocationStatus(context))
            }
            "openSettings" -> {
                PermissionHelper.openSettings(context)
                result.success(true)
            }
            "isLocationServiceEnabled" -> {
                val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                val gpsEnabled = try { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) } catch (e: Exception) { false }
                val networkEnabled = try { lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) } catch (e: Exception) { false }
                result.success(gpsEnabled || networkEnabled)
            }
            "getCurrentLocation" -> {
                locationService.getCurrentLocation(
                    onSuccess = { map -> result.success(map) },
                    onError = { err -> result.error("LOCATION_ERROR", err, null) }
                )
            }
            "startBackgroundTracking" -> {
                val title = call.argument<String>("notificationTitle") ?: "Navigation Active"
                val text = call.argument<String>("notificationText") ?: "Tracking location"

                val intent = Intent(context, TrackingForegroundService::class.java).apply {
                    action = TrackingForegroundService.ACTION_START
                    putExtra("title", title)
                    putExtra("text", text)
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(true)
            }
            "updateNotification" -> {
                val title = call.argument<String>("notificationTitle") ?: "Navigation Active"
                val text = call.argument<String>("notificationText") ?: "Tracking location"

                val intent = Intent(context, TrackingForegroundService::class.java).apply {
                    action = TrackingForegroundService.ACTION_UPDATE_NOTIFICATION
                    putExtra("title", title)
                    putExtra("text", text)
                }
                context.startService(intent)
                result.success(true)
            }
            "stopBackgroundTracking" -> {
                val intent = Intent(context, TrackingForegroundService::class.java).apply {
                    action = TrackingForegroundService.ACTION_STOP
                }
                context.startService(intent)
                result.success(true)
            }
            "getBackgroundTrackingStatus" -> {
                val statusMap = hashMapOf<String, Any>(
                    "isRunning" to TrackingForegroundService.isRunning,
                    "permissionGranted" to (PermissionHelper.checkLocationStatus(context) != "denied")
                )
                result.success(statusMap)
            }
            "getDiagnostics" -> {
                val lm = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                val diagnostics = hashMapOf<String, Any>(
                    "platform" to "Android",
                    "osVersion" to Build.VERSION.RELEASE,
                    "sdkVersion" to Build.VERSION.SDK_INT,
                    "locationPermission" to PermissionHelper.checkLocationStatus(context),
                    "isGpsEnabled" to (try { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) } catch (e: Exception) { false }),
                    "isBackgroundServiceRunning" to TrackingForegroundService.isRunning
                )
                result.success(diagnostics)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        locationEventChannel.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
