//
//  Copyright (c) Levin Li. All rights reserved.
//  Licensed under the MIT License.
//

import Foundation

public protocol JSONDecodable: Decodable {
    static var decoder: JSONDecoder? { get }
}

extension Array: JSONDecodable where Element: JSONDecodable {
    public static var decoder: JSONDecoder? { return Element.decoder }
}
