import Foundation

protocol EndpointProvider {
    func makeRequest() -> URLRequest?
    static var health: EndpointProvider { get }
    static var getSteps: EndpointProvider { get }
    static var postSteps: EndpointProvider { get }
    static var deleteSteps: EndpointProvider { get }
}

extension EndpointProvider where Self == LocalEndpoint {
    static var health: any EndpointProvider { LocalEndpoint._health }
    static var getSteps: any EndpointProvider { LocalEndpoint._getSteps }
    static var postSteps: any EndpointProvider { LocalEndpoint._postSteps }
    static var deleteSteps: any EndpointProvider { LocalEndpoint._deleteSteps }
}

/// API endpoints for health step sync
enum LocalEndpoint: EndpointProvider {
    struct Constants {
        // static var baseURL: String = "http://127.0.0.1:8000"  // Simulator
        static var baseURL: String = "http://192.168.0.200:8000"  // Physical device - update IP as needed
    }

    case _health
    case _getSteps
    case _postSteps
    case _deleteSteps

    var path: String {
        switch self {
        case ._health:
            return "/health"
        case ._getSteps, ._postSteps, ._deleteSteps:
            return "/steps"
        }
    }

    var httpMethod: String {
        switch self {
        case ._health, ._getSteps:
            return "GET"
        case ._postSteps:
            return "POST"
        case ._deleteSteps:
            return "DELETE"
        }
    }

    var url: URL? {
        URL(string: Constants.baseURL + path)
    }

    func makeRequest() -> URLRequest? {
        guard let url = url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod

        if httpMethod == "POST" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }
}
