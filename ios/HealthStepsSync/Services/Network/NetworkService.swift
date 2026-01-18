import Foundation

protocol NetworkService {
    /// Performs a GET request to the specified endpoint
    func get<Response: Decodable>(_ endpoint: EndpointProvider) async throws -> Response

    /// Performs a POST request with an encoded body
    @discardableResult
    func post<Request: Encodable>(_ endpoint: EndpointProvider, body: Request) async throws -> PostResponse

    /// Performs a DELETE request to the specified endpoint
    @discardableResult
    func delete(_ endpoint: EndpointProvider) async throws -> DeleteResponse
}
