import Flutter
import UIKit
import CoreLocation

public class FlutterMapNavigatorPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.flutter_map_navigator/methods", binaryMessenger: registrar.messenger())
        let instance = FlutterMapNavigatorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        let eventChannel = FlutterEventChannel(name: "com.flutter_map_navigator/location_stream", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let locManager = LocationManager.shared

        switch call.method {
        case "getLocationPermissionStatus":
            result(locManager.getPermissionStatus())

        case "requestWhenInUseAuthorization":
            locManager.requestWhenInUseAuthorization()
            result(true)

        case "requestAlwaysAuthorization":
            locManager.requestAlwaysAuthorization()
            result(true)

        case "openSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            result(true)

        case "isLocationServiceEnabled":
            result(locManager.isLocationServicesEnabled())

        case "getCurrentLocation":
            locManager.getCurrentLocation { res in
                switch res {
                case .success(let map):
                    result(map)
                case .failure(let err):
                    result(FlutterError(code: "LOCATION_ERROR", message: err.localizedDescription, details: nil))
                }
            }

        case "startBackgroundTracking":
            locManager.startBackgroundTracking()
            result(true)

        case "stopBackgroundTracking":
            locManager.stopBackgroundTracking()
            result(true)

        case "getBackgroundTrackingStatus":
            let status: [String: Any] = [
                "isRunning": locManager.isBackgroundTrackingRunning,
                "permissionGranted": locManager.getPermissionStatus() == "background" || locManager.getPermissionStatus() == "precise"
            ]
            result(status)

        case "getDiagnostics":
            let diagnostics: [String: Any] = [
                "platform": "iOS",
                "osVersion": UIDevice.current.systemVersion,
                "locationPermission": locManager.getPermissionStatus(),
                "isLocationServicesEnabled": locManager.isLocationServicesEnabled(),
                "isBackgroundServiceRunning": locManager.isBackgroundTrackingRunning
            ]
            result(diagnostics)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        LocationManager.shared.onLocationUpdate = { [weak self] locationMap in
            self?.eventSink?(locationMap)
        }
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        LocationManager.shared.onLocationUpdate = nil
        return nil
    }
}
