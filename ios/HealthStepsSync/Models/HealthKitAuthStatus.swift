import Foundation

/// Authorization status for HealthKit access
enum HealthKitAuthStatus {
    case notDetermined
    case authorized
    case denied
    case unavailable

    // MARK: - UI Strings

    var title: String {
        switch self {
        case .notDetermined:
            return "Authorization Required"
        case .authorized:
            return "Ready to sync steps"
        case .denied:
            return "Access Denied"
        case .unavailable:
            return "HealthKit Unavailable"
        }
    }

    var description: String {
        switch self {
        case .notDetermined:
            return "Grant access to HealthKit to sync your step data"
        case .authorized:
            return ""
        case .denied:
            return "Enable HealthKit access in Settings to sync your steps"
        case .unavailable:
            return "HealthKit is not available on this device"
        }
    }

    var systemImage: String {
        switch self {
        case .notDetermined:
            return "heart.text.square"
        case .authorized:
            return "figure.walk"
        case .denied:
            return "hand.raised"
        case .unavailable:
            return "exclamationmark.triangle"
        }
    }

    var buttonText: String? {
        switch self {
        case .notDetermined:
            return "Allow Access"
        case .denied:
            return "Open Settings"
        case .authorized, .unavailable:
            return nil
        }
    }
}
