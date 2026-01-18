import Foundation

/// Represents a step sample in the API format, matching the server schema
struct APIStepSample: Codable {
    let uuid: String
    let startDate: String  // ISO 8601 format with Z
    let endDate: String    // ISO 8601 format with Z
    let count: Int
    let sourceBundleId: String
    let sourceDeviceName: String?
}

/// Request payload for POST /steps
struct PostStepsRequest: Codable {
    let samples: [APIStepSample]
}

/// Response payload for POST /steps
struct PostResponse: Codable {
    let saved: Int
    let message: String
}

/// Response payload for GET /steps
struct GetStepsResponse: Codable {
    let samples: [APIStepSample]
    let total: Int
}

/// Response payload for DELETE /steps
struct DeleteResponse: Codable {
    let message: String
}

/// Response payload for GET /health
struct HealthCheckResponse: Codable {
    let status: String
}

/// Error response from API
struct APIErrorResponse: Codable {
    let error: String
}
