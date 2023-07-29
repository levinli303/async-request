//
//  Copyright (c) Levin Li. All rights reserved.
//  Licensed under the MIT License.
//

import AsyncHTTPClient
import Foundation
import NIO
import NIOHTTP1

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

extension HTTPClient {
    func get(from url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> HTTPClientResponse {
        let newURL = try URL.from(url: url, parameters: parameters)
        var request = HTTPClientRequest(url: newURL.absoluteString)
        request.method = .GET
        for (key, value) in headers ?? [:] {
            request.headers.replaceOrAdd(name: key, value: value)
        }
        return try await execute(request, timeout: configuration.resolvedTimeout)
    }

    func post(to url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> HTTPClientResponse {
        let newURL = try URL.from(url: url)
        var request = HTTPClientRequest(url: newURL.absoluteString)
        try request.setPostParameters(parameters)
        for (key, value) in headers ?? [:] {
            request.headers.replaceOrAdd(name: key, value: value)
        }
        return try await execute(request, timeout: configuration.resolvedTimeout)
    }

    func post<T: Encodable>(to url: String, json: T, encoder: JSONEncoder?, headers: [String: String]?, configuration: RequestConfiguration) async throws -> HTTPClientResponse {
        let newURL = try URL.from(url: url)
        var request = HTTPClientRequest(url: newURL.absoluteString)
        try request.setPostParametersJson(json, encoder: encoder)

        for (key, value) in headers ?? [:] {
            request.headers.replaceOrAdd(name: key, value: value)
        }
        return try await execute(request, timeout: configuration.resolvedTimeout)
    }

    func upload(to url: String, parameters: [String: String], data: Data, key: String, filename: String, headers: [String: String]?, configuration: RequestConfiguration) async throws -> HTTPClientResponse {
        let newURL = try URL.from(url: url)
        var request = HTTPClientRequest(url: newURL.absoluteString)
        try request.setUploadParameters(parameters, data: data, key: key, filename: filename)
        for (key, value) in headers ?? [:] {
            request.headers.replaceOrAdd(name: key, value: value)
        }
        return try await execute(request, timeout: configuration.resolvedTimeout)
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

    mutating func setUploadParameters(_ parameters: [String: String], data: Data, key: String, filename: String) throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        let mimeType = "application/octet-stream"

        /* Create upload body */
        var body = Data()

        func appendString(_ string: String) throws {
            guard let data = string.data(using: .utf8) else {
                throw RequestError.urlError
            }
            body.append(data)
        }

        /* Key/value pairs */
        let boundaryPrefix = "--\(boundary)\r\n"
        for (key, value) in parameters {
            try appendString(boundaryPrefix)
            try appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            try appendString("\(value)\r\n")
        }
        /* File information */
        try appendString(boundaryPrefix)
        try appendString("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(filename)\"\r\n")
        try appendString("Content-Type: \(mimeType)\r\n\r\n")
        /* File data */
        body.append(data)
        try appendString("\r\n")
        try appendString("--".appending(boundary.appending("--")))

        method = .POST
        self.body = .bytes(body)
        headers.replaceOrAdd(name: "Content-Length", value: "\(body.count)")
        headers.replaceOrAdd(name: "Content-Type", value: "multipart/form-data; boundary=\(boundary)")
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
