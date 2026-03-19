//
//  Copyright (c) Levin Li. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

public protocol RequestClient {
    func get(from url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse
    func post(to url: String, parameters: [String: String], headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse
    func post<T: Encodable>(to url: String, json: T, encoder: JSONEncoder?, headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse
    func upload(to url: String, parameters: [String: String], data: Data, key: String, filename: String, headers: [String: String]?, configuration: RequestConfiguration) async throws -> ClientResponse
}

public protocol ClientResponse {
    var statusCode: UInt { get }
    var statusReasonPhrase: String { get }
    func getBodyData() async throws -> Data
}

extension URL {
    static func from(url: String, parameters: [String: String] = [:]) throws -> URL {
        if parameters.isEmpty {
            guard let newURL = URL(string: url) else {
                throw RequestError.urlError
            }
            return newURL
        }
        guard var components = URLComponents(string: url) else {
            throw RequestError.urlError
        }
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let newURL = components.url else {
            throw RequestError.urlError
        }
        return newURL
    }
}
