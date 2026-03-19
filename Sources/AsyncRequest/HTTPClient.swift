//
//  Copyright (c) Levin Li. All rights reserved.
//  Licensed under the MIT License.
//

#if AsyncHTTPClient
import AsyncHTTPClient
import Foundation
import NIO
import NIOHTTP1

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

    public func upload(to url: String, parameters: [String: String], data: Data, key: String, filename: String, headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url)
        var request = HTTPClientRequest(url: newURL.absoluteString)
        try request.setUploadParameters(parameters, data: data, key: key, filename: filename)
        for (key, value) in headers ?? [:] {
            request.headers.replaceOrAdd(name: key, value: value)
        }
        return try await execute(request, timeout: configuration.resolvedTimeout)
    }
}

extension HTTPClientResponse: ClientResponse {
    public var statusCode: UInt { status.code }
    public var statusReasonPhrase: String { status.reasonPhrase }
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

    mutating func setUploadParameters(_ parameters: [String: String], data: Data, key: String, filename: String) throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        let mimeType = "application/octet-stream"

        var body = Data()

        func appendString(_ string: String) throws {
            guard let data = string.data(using: .utf8) else {
                throw RequestError.urlError
            }
            body.append(data)
        }

        let boundaryPrefix = "--\(boundary)\r\n"
        for (key, value) in parameters {
            try appendString(boundaryPrefix)
            try appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            try appendString("\(value)\r\n")
        }
        try appendString(boundaryPrefix)
        try appendString("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(filename)\"\r\n")
        try appendString("Content-Type: \(mimeType)\r\n\r\n")
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
#endif
