//
//  Copyright (c) Levin Li. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation
import NIO

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
open class AsyncBaseRequestHandler<Output> {
    private class func commonHandler(response: ClientResponse) async throws -> Output {
        let data: Data
        do {
            data = try await response.getBodyData()
        } catch {
            throw RequestError.bodyData
        }
        let statusCode = response.status.code
        guard statusCode < 400 else {
            throw RequestError.httpError(statusCode: statusCode, errorString: HTTPURLResponse.localizedString(forStatusCode: Int(statusCode)), responseBody: data)
        }
        return try await handleData(data)
    }

    open class func handleData(_ data: Data) async throws -> Output {
        fatalError("Subclass should implement handleData:")
    }

    public class func get(url: String,
                          parameters: [String: String] = [:],
                          headers: [String: String]? = nil,
                          configuration: RequestConfiguration = RequestConfiguration(),
                          httpClient: RequestClient) async throws -> Output {
        let response: ClientResponse
        do {
            response = try await httpClient.get(from: url, parameters: parameters, headers: headers, configuration: configuration)
        } catch {
            throw RequestError.urlSessionError(error: error)
        }
        let result: Result<Output, Error>
        do {
            result = .success(try await commonHandler(response: response))
        } catch {
            result = .failure(error)
        }
        return try result.get()
    }

    public class func post(url: String,
                           parameters: [String: String] = [:],
                           headers: [String: String]? = nil,
                           configuration: RequestConfiguration = RequestConfiguration(),
                           httpClient: RequestClient) async throws -> Output {
        let response: ClientResponse
        do {
            response = try await httpClient.post(to: url, parameters: parameters, headers: headers, configuration: configuration)
        } catch {
            throw RequestError.urlSessionError(error: error)
        }
        let result: Result<Output, Error>
        do {
            result = .success(try await commonHandler(response: response))
        } catch {
            result = .failure(error)
        }
        return try result.get()
    }

    public class func post<T: Encodable>(url: String,
                                         json: T,
                                         encoder: JSONEncoder? = nil,
                                         headers: [String: String]? = nil,
                                         configuration: RequestConfiguration = RequestConfiguration(),
                                         httpClient: RequestClient) async throws -> Output {
        let response: ClientResponse
        do {
            response = try await httpClient.post(to: url, json: json, encoder: encoder, headers: headers, configuration: configuration)
        } catch {
            throw RequestError.urlSessionError(error: error)
        }
        let result: Result<Output, Error>
        do {
            result = .success(try await commonHandler(response: response))
        } catch {
            result = .failure(error)
        }
        return try result.get()
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public class AsyncEmptyRequestHandler: AsyncBaseRequestHandler<Void> {
    public override class func handleData(_ data: Data) async throws -> Void {
        return ()
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public class AsyncDataRequestHandler: AsyncBaseRequestHandler<Data> {
    public override class func handleData(_ data: Data) async throws -> Data {
        return data
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public class AsyncJSONRequestHandler<Output>: AsyncBaseRequestHandler<Output> where Output: JSONDecodable {

    public override class func handleData(_ data: Data) async throws -> Output {
        do {
            return try (Output.decoder ?? JSONDecoder()).decode(Output.self, from: data)
        } catch {
            throw RequestError.decodingError(error: error)
        }
    }
}
