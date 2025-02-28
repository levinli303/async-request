//
//  Copyright (c) Levin Li. All rights reserved.
//  Licensed under the MIT License.
//

import AsyncHTTPClient
import Foundation
import NIO
import NIOHTTP1
import Vapor

public protocol RequestClient {
    func get(from url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse
    func post(to url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse
    func post<T: Encodable>(to url: String, json: T, encoder: JSONEncoder?, headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse
}

public protocol ClientResponse {
    var status: HTTPStatus { get }
    func getBodyData() async throws -> Data
}

private extension URL {
    static func from(url: String, parameters: [String: String] = [:]) throws -> URL {
        if parameters.count == 0 {
            guard let newURL = URL(string: url) else {
                throw RequestError.urlError
            }
            return newURL
        }
        guard var components = URLComponents(string: url) else {
            throw RequestError.urlError
        }
        components.queryItems = parameters.count == 0 ? nil : parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let newURL = components.url else {
            throw RequestError.urlError
        }
        return newURL
    }
}

extension HTTPClient: RequestClient {
    public func get(from url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url, parameters: parameters)
        var request = HTTPClientRequest(url: newURL.absoluteString)
        request.method = .GET
        for (key, value) in headers ?? [:] {
            request.headers.replaceOrAdd(name: key, value: value)
        }
        return try await execute(request, timeout: configuration.resolvedTimeout)
    }

    public func post(to url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url)
        var request = HTTPClientRequest(url: newURL.absoluteString)
        try request.setPostParameters(parameters)
        for (key, value) in headers ?? [:] {
            request.headers.replaceOrAdd(name: key, value: value)
        }
        return try await execute(request, timeout: configuration.resolvedTimeout)
    }

    public func post<T: Encodable>(to url: String, json: T, encoder: JSONEncoder?, headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url)
        var request = HTTPClientRequest(url: newURL.absoluteString)
        try request.setPostParametersJson(json, encoder: encoder)

        for (key, value) in headers ?? [:] {
            request.headers.replaceOrAdd(name: key, value: value)
        }
        return try await execute(request, timeout: configuration.resolvedTimeout)
    }
}

extension HTTPClientResponse: ClientResponse {
    public func getBodyData() async throws -> Data {
        var data = Data()
        for try await buffer in body {
            data.append(contentsOf: buffer.readableBytesView)
        }
        return data
    }
}

private extension HTTPClientRequest {
    mutating func setPostParametersJson<T: Encodable>(_ encodable: T, encoder: JSONEncoder?) throws {
        method = .POST
        headers.replaceOrAdd(name: "Content-Type", value: "application/json; charset=utf-8")
        do {
            body = .bytes(try (encoder ?? JSONEncoder()).encode(encodable))
        } catch {
            throw RequestError.urlError
        }
    }

    mutating func setPostParameters(_ parameters: [String: String]) throws {
        method = .POST
        headers.replaceOrAdd(name: "Content-Type", value: "application/x-www-form-urlencoded")
        let query = try parameters.map({ (key, value) -> String in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw RequestError.urlError
            }
            return "\(encodedKey)=\(encodedValue)"
        }).joined(separator: "&")
        if query.isEmpty {
            body = nil
        } else {
            guard let data = query.data(using: .utf8) else {
                throw RequestError.urlError
            }
            body = .bytes(data)
        }
    }
}

private extension RequestConfiguration {
    var resolvedTimeout: TimeAmount {
        if let timeout {
            return .seconds(Int64(timeout))
        }
        return .seconds(60)
    }
}

public class VaporClientWrapper {
    private let client: any Client

    public init(client: any Client) {
        self.client = client
    }
}

extension VaporClientWrapper: RequestClient {
    public func get(from url: String, parameters: [String : String], headers: [String : String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url, parameters: parameters)
        var httpHeaders = HTTPHeaders()
        for (key, value) in headers ?? [:] {
            httpHeaders.add(name: key, value: value)
        }
        return try await client.get(URI(string: newURL.absoluteString), headers: httpHeaders) { request in
            request.timeout = configuration.resolvedTimeout
        }
    }

    public func post(to url: String, parameters: [String : String], headers: [String : String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url)
        var httpHeaders = HTTPHeaders()
        for (key, value) in headers ?? [:] {
            httpHeaders.add(name: key, value: value)
        }
        return try await client.post(URI(string: newURL.absoluteString), headers: httpHeaders) { request in
            try request.content.encode(parameters, as: .formData(boundary: "Boundary-\(UUID().uuidString)"))
            request.timeout = configuration.resolvedTimeout
        }
    }

    public func post<U>(to url: String, json: U, encoder: JSONEncoder?, headers: [String : String]?, configuration: RequestConfiguration) async throws -> ClientResponse where U : Encodable {
        let newURL = try URL.from(url: url)
        var httpHeaders = HTTPHeaders()
        for (key, value) in headers ?? [:] {
            httpHeaders.add(name: key, value: value)
        }
        return try await client.post(URI(string: newURL.absoluteString), headers: httpHeaders) { request in
            try request.content.encode(json, as: .json)
            request.timeout = configuration.resolvedTimeout
        }
    }
}

extension Vapor.ClientResponse: ClientResponse {
    public func getBodyData() async throws -> Data {
        var data = Data()
        guard let bytesView = body?.readableBytesView else { return data }
        data.append(contentsOf: bytesView)
        return data
    }
}

