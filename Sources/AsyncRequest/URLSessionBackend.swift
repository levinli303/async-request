//
//  Copyright (c) Levin Li. All rights reserved.
//  Licensed under the MIT License.
//

#if USE_URL_SESSION
import Foundation

private struct URLSessionClientResponse: ClientResponse, Sendable {
    let data: Data
    let code: UInt
    let reasonPhrase: String

    var statusCode: UInt { code }
    var statusReasonPhrase: String { reasonPhrase }
    func getBodyData() async throws -> Data { data }
}

extension URLSession: RequestClient {
    public func get(from url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url, parameters: parameters)
        var request = URLRequest(url: newURL)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.resolvedTimeoutInterval
        for (key, value) in headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return try await perform(request)
    }

    public func post(to url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url)
        var request = URLRequest(url: newURL)
        try request.setPostParameters(parameters)
        request.timeoutInterval = configuration.resolvedTimeoutInterval
        for (key, value) in headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return try await perform(request)
    }

    public func post<T: Encodable>(to url: String, json: T, encoder: JSONEncoder?, headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url)
        var request = URLRequest(url: newURL)
        try request.setPostParametersJson(json, encoder: encoder)
        request.timeoutInterval = configuration.resolvedTimeoutInterval
        for (key, value) in headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return try await perform(request)
    }

    public func upload(to url: String, parameters: [String: String], data: Data, key: String, filename: String, headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse {
        let newURL = try URL.from(url: url)
        var request = URLRequest(url: newURL)
        try request.setUploadParameters(parameters, data: data, key: key, filename: filename)
        request.timeoutInterval = configuration.resolvedTimeoutInterval
        for (key, value) in headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: key)
        }
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> ClientResponse {
        let (data, response) = try await data(for: request, delegate: nil)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RequestError.noResponse
        }
        return URLSessionClientResponse(
            data: data,
            code: UInt(httpResponse.statusCode),
            reasonPhrase: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
        )
    }
}

fileprivate extension URLRequest {
    mutating func setPostParametersJson<T: Encodable>(_ encodable: T, encoder: JSONEncoder?) throws {
        httpMethod = "POST"
        setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        do {
            httpBody = try (encoder ?? JSONEncoder()).encode(encodable)
        } catch {
            throw RequestError.urlError
        }
    }

    mutating func setPostParameters(_ parameters: [String: String]) throws {
        httpMethod = "POST"
        setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let query = try parameters.map({ (key, value) -> String in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw RequestError.urlError
            }
            return "\(encodedKey)=\(encodedValue)"
        }).joined(separator: "&")
        httpBody = query.isEmpty ? nil : query.data(using: .utf8)
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
        for (paramKey, value) in parameters {
            try appendString(boundaryPrefix)
            try appendString("Content-Disposition: form-data; name=\"\(paramKey)\"\r\n\r\n")
            try appendString("\(value)\r\n")
        }
        try appendString(boundaryPrefix)
        try appendString("Content-Disposition: form-data; name=\"\(key)\"; filename=\"\(filename)\"\r\n")
        try appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        try appendString("\r\n")
        try appendString("--".appending(boundary.appending("--")))

        httpMethod = "POST"
        httpBody = body
        setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    }
}

private extension RequestConfiguration {
    var resolvedTimeoutInterval: TimeInterval {
        timeout ?? 60
    }
}
#endif
