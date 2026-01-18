//
//  NetworkServiceError.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import Foundation

enum NetworkServiceError: Error, LocalizedError {
    case badURL(EndpointProvider)
    case httpError(statusCode: Int, body: String)
    case decodingError(Error)
    case encodingError(Error)

    var errorDescription: String? {
        switch self {
        case .badURL(let endpoint):
            "Bad URL for endpoint: \(endpoint)."
        case .httpError(let statusCode, let body):
            "HTTP Error \(statusCode): \(body)"
        case .decodingError(let error):
            "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            "Failed to encode request: \(error.localizedDescription)"
        }
    }
}
