//
//  Copyright (c) Levin Li. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

public enum RequestError: Error {
    case noResponse
    case urlError
    case httpError(statusCode: UInt, errorString: String, responseBody: Data)
    case bodyData
    case urlSessionError(error: Error)
    case decodingError(error: Error)
    case unknown
}

extension RequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .urlError:
            return NSLocalizedString("Incorrect URL", comment: "")
        case .noResponse:
            return NSLocalizedString("No response", comment: "")
        case .decodingError(let error):
            return error.localizedDescription
        case .httpError(_, let errorString, _):
            return errorString
        case .urlSessionError(let error):
            return error.localizedDescription
        case .unknown:
            return NSLocalizedString("Unknown error", comment: "")
        case .bodyData:
            return NSLocalizedString("Error getting body data", comment: "")
        }
    }
}
