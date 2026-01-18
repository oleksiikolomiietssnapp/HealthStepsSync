//
//  URLSessionNetworkService 2.swift
//  HealthStepsSync
//
//  Created by Oleksii Kolomiiets on 1/17/26.
//

import Foundation

class URLSessionNetworkService: NetworkService {
    private let session: URLSession
    private let decoder: JSONDecoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    func get<Response: Decodable>(_ endpoint: EndpointProvider) async throws -> Response {
        guard let request = endpoint.makeRequest() else {
            throw NetworkServiceError.badURL(endpoint)
        }

        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkServiceError.decodingError(error)
        }
    }

    func post<Request: Encodable, Response: Decodable>(_ endpoint: EndpointProvider, body: Request) async throws -> Response {
        guard var request = endpoint.makeRequest() else {
            throw NetworkServiceError.badURL(endpoint)
        }

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw NetworkServiceError.encodingError(error)
        }

        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkServiceError.decodingError(error)
        }
    }

    func delete<Response: Decodable>(_ endpoint: EndpointProvider) async throws -> Response {
        guard let request = endpoint.makeRequest() else {
            throw NetworkServiceError.badURL(endpoint)
        }

        let (data, response) = try await session.data(for: request)

        try validateResponse(response)

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkServiceError.decodingError(error)
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkServiceError.httpError(statusCode: 0, body: "Invalid response type")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            let body = "HTTP \(httpResponse.statusCode)"
            throw NetworkServiceError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }
}
