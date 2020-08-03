//
//  Utilities.swift
//  
//
//  Created by Emma K Alexandra on 8/3/20.
//

import Foundation

/// To retrieve the bytes of data
extension Data {
    var bytes : [UInt8]{
        return [UInt8](self)

    }

}

/// To convert large unsigned ints to 0 padded strings
extension UInt64 {
    func toPaddedString() -> String {
        return String(format: "%019ld", self)

    }

}

/// To convert ints to 0 padded strings
extension Int {
    func toPaddedString() -> String {
        return String(format: "%019d", self)

    }

}
