import Foundation

protocol NetworkService {
    /// Performs a GET request to the specified endpoint
    func get<Response: Decodable>(_ endpoint: EndpointProvider) async throws -> Response

    /// Performs a POST request with an encoded body
    func post<Request: Encodable, Response: Decodable>(_ endpoint: EndpointProvider, body: Request) async throws -> Response

    /// Performs a DELETE request to the specified endpoint
    func delete(_ endpoint: EndpointProvider) async throws -> DeleteStepsResponse
}

extension NetworkService where Self == URLSessionNetworkService {
    static var live: Self {
        URLSessionNetworkService()
    }
}
