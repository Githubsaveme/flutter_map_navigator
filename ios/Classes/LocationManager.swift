import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let clManager = CLLocationManager()
    var onLocationUpdate: (([String: Any]) -> Void)?
    var onAuthStatusChange: ((String) -> Void)?

    private(set) var isBackgroundTrackingRunning = false

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        clManager.distanceFilter = kCLDistanceFilterNone
    }

    func requestWhenInUseAuthorization() {
        clManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        clManager.requestAlwaysAuthorization()
    }

    func getPermissionStatus() -> String {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = clManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "background"
        case .authorizedWhenInUse:
            if #available(iOS 14.0, *) {
                return clManager.accuracyAuthorization == .fullAccuracy ? "precise" : "approximate"
            }
            return "foreground"
        @unknown default:
            return "unknown"
        }
    }

    func isLocationServicesEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }

    func startBackgroundTracking() {
        clManager.allowsBackgroundLocationUpdates = true
        clManager.showsBackgroundLocationIndicator = true
        clManager.pausesLocationUpdatesAutomatically = false
        clManager.startUpdatingLocation()
        clManager.startUpdatingHeading()
        isBackgroundTrackingRunning = true
    }

    func stopBackgroundTracking() {
        clManager.allowsBackgroundLocationUpdates = false
        clManager.stopUpdatingLocation()
        clManager.stopUpdatingHeading()
        isBackgroundTrackingRunning = false
    }

    func getCurrentLocation(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        if let location = clManager.location {
            completion(.success(locationToMap(location: location, heading: clManager.heading?.trueHeading)))
        } else {
            clManager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let map = locationToMap(location: location, heading: manager.heading?.trueHeading)
        onLocationUpdate?(map)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        if let location = manager.location {
            let map = locationToMap(location: location, heading: newHeading.trueHeading)
            onLocationUpdate?(map)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let statusStr = getPermissionStatus()
        onAuthStatusChange?(statusStr)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[FlutterMapNavigator] CoreLocation error: \(error.localizedDescription)")
    }

    private func locationToMap(location: CLLocation, heading: CLLocationDirection?) -> [String: Any] {
        var map: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "accuracy": location.horizontalAccuracy,
            "altitude": location.altitude,
            "speed": location.speed >= 0 ? location.speed : 0.0,
            "heading": heading ?? (location.course >= 0 ? location.course : 0.0),
            "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000)
        ]
        return map
    }
}
