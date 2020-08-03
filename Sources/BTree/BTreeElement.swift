//
//  BTreeElement.swift
//  
//
//  Created by Emma K Alexandra on 8/3/20.
//

import Foundation

/// Elements of the B-Tree
public struct BTreeElement<Key: Comparable & Codable, Value: Codable>: Codable {
    /// Codable and Comparable key to use for lookups
    public let key: Key

    /// Optional value to store along with key.
    public let value: Value

    public init(key: Key, value: Value) {
        self.key = key
        self.value = value

    }

}
