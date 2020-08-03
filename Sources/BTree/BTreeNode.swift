//
//  BTreeNode.swift
//  
//
//  Created by Emma K Alexandra on 8/3/20.
//

import Foundation

/// A node in the B-Tree
public struct BTreeNode<Key: Comparable & Codable, Value: Codable>: Codable {

    // MARK: Properties

    typealias Hatchimals = Hashable // my wife made me do this

    /// The elements in this node
    public var elements = [BTreeElement<Key, Value>]()

    /// The children nodes of this node
    public var children = [BTreeNode<Key, Value>]()

    /// The minimum degree of this node. See README for details.
    public var minimumDegree: Int

    /// If this node is a leaf
    public var isLeaf: Bool { self.children.count == 0 }

    /// If this node is full of elements.
    public var isFull: Bool { self.elements.count == (2 * self.minimumDegree - 1) }

    /// If this node's elements and children are loaded from disk.
    public var isLoaded = false

    /// If this node is the root of the tree
    public var isRoot: Bool

    /// Offset of this node in storage engine
    public var offset: UInt64? = nil

    /// The storage engine used by this node.
    unowned var storage: Storage<Key, Value>? = nil

    /// We only want to serialize a few fields from this node.
    enum CodingKeys: String, CodingKey {
        case elements
        case children
        case minimumDegree
        case isLeaf
    }

    // MARK: Creation

    /// Initializer used to load this node from disk.
    public init(from decoder: Decoder) throws {
        self.isRoot = false
        self.isLoaded = true

        let values = try decoder.container(keyedBy: CodingKeys.self)

        self.elements = try values.decode([BTreeElement].self, forKey: .elements)

        self.minimumDegree = try values.decode(Int.self, forKey: .minimumDegree)

        let decodedChildren = try values.decode([String].self, forKey: .children)

        self.children = try decodedChildren.map({ (childOffsetString) -> BTreeNode in
            guard let childOffset = UInt64(childOffsetString) else {
                throw BTreeError.invalidRecord
            }

            var child = BTreeNode(minimumDegree: self.minimumDegree, isRoot: false)
            child.offset = childOffset

            return child
        })
    }

    /// Set up a new node
    ///
    /// - parameter minimumDegree: The minimum degree of this node. See README for details.
    /// - parameter isLeaf: If this node is a leaf
    /// - parameter isLoaded: If this node is loaded from storage.
    /// - parameter storage: The storage engine used by this node.
    public init(minimumDegree: Int, isRoot: Bool, isLoaded: Bool = false, storage: Storage<Key, Value>? = nil) {
        self.minimumDegree = minimumDegree
        self.isLoaded = isLoaded
        self.isRoot = isRoot
        self.storage = storage
    }

    // MARK: Find

    /// Find a key in this node
    ///
    /// - parameter key: Key to find in this node
    /// - returns: Value matching the given key
    /// - throws: `BTreeError.unableToLoadNode` if unable to load any nodes from disk used for this find.
    public mutating func find(_ key: Key) throws -> Value? {
        var i = 0

        while i < self.elements.count, self.elements[i].key < key  {
            i += 1
        }

        if i < self.elements.count, key == self.elements[i].key {
            return self.elements[i].value
        } else if self.isLeaf {
            return nil
        } else {
            self.children[i].storage = self.storage
            try self.children[i].load()

            return try self.children[i].find(key)
        }
    }

    // MARK: Insert

    /// Inserts an element in to this node, if the node is not full.
    ///
    /// - parameter newElement: Element to insert into this node
    /// - throws: `BTreeError.unableToLoadNode` if unable to load any nodes used in this insert
    public mutating func insertNonFull(_ newElement: BTreeElement<Key, Value>) throws {
        var i = 0

        if self.isLeaf {
            while i < self.elements.count, self.elements[i].key < newElement.key {
                i += 1
            }

            if i < self.elements.count, newElement.key == self.elements[i].key {
                throw BTreeError.duplicateKey
            }

            self.elements.insert(newElement, at: i)

            try self.save()

        } else {
            while i < self.elements.count, self.elements[i].key < newElement.key {
                i += 1
            }

            self.children[i].storage = self.storage

            try self.children[i].load()

            if self.children[i].isFull {
                try self.split(at: i)
                if self.elements[i].key < newElement.key  {
                    i += 1
                }
            }

            try self.children[i].insertNonFull(newElement)

            try self.save()
        }
    }

    /// Splits the given child of this node.
    ///
    /// - parameter childIndex: The index of the child to split
    /// - throws: If unable to load any nodes used in this split, or if storage engine is unable to write to disk.
    public mutating func split(at childIndex: Int) throws {
        var newChild = BTreeNode(minimumDegree: self.minimumDegree, isRoot: false, isLoaded: true, storage: self.storage!)

        let elementsToTransferRange = self.minimumDegree...
        newChild.elements = Array(self.children[childIndex].elements[elementsToTransferRange])
        self.children[childIndex].elements.removeSubrange(elementsToTransferRange)

        if !self.children[childIndex].isLeaf {
            let childrenToTransferRange = self.minimumDegree...
            newChild.children = Array(self.children[childIndex].children[childrenToTransferRange])
            self.children[childIndex].children.removeSubrange(childrenToTransferRange)

        }

        self.elements.insert(self.children[childIndex].elements.removeLast(), at: childIndex)

        try self.children[childIndex].save()
        try newChild.save()

        self.children.insert(newChild, at: childIndex + 1)

        try self.save()

    }

    // MARK: Disk Operations

    /// Encode this node into JSON
    ///
    /// - parameter to: Encoder to use
    /// - throws: If unable to encode this node.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.elements, forKey: .elements)
        try container.encode(self.children.map { $0.offset!.toPaddedString() }, forKey: .children)
        try container.encode(self.minimumDegree, forKey: .minimumDegree)
    }

    /// Save this node to disk using storage engine
    ///
    /// - throws: If unable to load this node, or if storage engine is unable to write to disk
    public mutating func save() throws {
        guard let storage = self.storage, self.isLoaded else {
            throw BTreeError.nodeIsNotLoaded
        }

        if self.isRoot {
            self.offset = try storage.saveRoot(self)
        } else {
            self.offset = try storage.append(self)
        }
    }

    /// Loads this node from disk using storage engine
    ///
    /// - throws: If unable to load node
    public mutating func load() throws {
        guard let storage = self.storage, let offset = self.offset else {
            throw BTreeError.unableToLoadNode
        }

        if self.isLoaded { return }

        let node = try storage.findNode(withOffset: offset)

        self.elements = node.elements
        self.children = node.children
        self.minimumDegree = node.minimumDegree
        self.isLoaded = true
    }
}
