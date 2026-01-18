import Foundation

extension StepSample {
    /// Converts this StepSample to an APIStepSample for sending to the API
    /// - Parameter sourceDeviceName: Optional device name from HealthKit
    /// - Returns: APIStepSample ready for JSON encoding
    func toAPIModel(sourceDeviceName: String? = nil) -> APIStepSample {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return APIStepSample(
            uuid: id.uuidString,
            startDate: formatter.string(from: startDate),
            endDate: formatter.string(from: endDate),
            count: count,
            sourceBundleId: sourceBundleId,
            sourceDeviceName: sourceDeviceName
        )
    }

    /// Creates a StepSample from an APIStepSample received from the API
    /// - Parameter apiModel: The APIStepSample from the API response
    /// - Returns: A new StepSample marked as synced
    /// - Throws: DecodingError if dates cannot be parsed
    static func fromAPIModel(_ apiModel: APIStepSample) throws -> StepSample {
        let formatter = ISO8601DateFormatter()

        guard let uuid = UUID(uuidString: apiModel.uuid) else {
            throw APIDecodingError.invalidUUID(apiModel.uuid)
        }

        guard let startDate = formatter.date(from: apiModel.startDate) else {
            throw APIDecodingError.invalidDate(apiModel.startDate)
        }

        guard let endDate = formatter.date(from: apiModel.endDate) else {
            throw APIDecodingError.invalidDate(apiModel.endDate)
        }

        return StepSample(
            id: uuid,
            startDate: startDate,
            endDate: endDate,
            count: apiModel.count,
            sourceBundleId: apiModel.sourceBundleId,
            healthKitUUID: UUID(),  // Placeholder - actual value should come from HealthKit
            isSynced: true,
            syncedAt: Date()
        )
    }
}

/// Errors that can occur during API model decoding
enum APIDecodingError: Error {
    case invalidUUID(String)
    case invalidDate(String)
}
