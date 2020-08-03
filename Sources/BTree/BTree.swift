//
//  BTree.swift
//
//
//  Created by Emma K Alexandra on 7/4/19.
import Foundation

/// Main implementation of a B-Tree
public class BTree<Key: Comparable & Codable, Value: Codable> {
    
    // MARK: Properties
    
    /// Convenience. Pass through for te minimum degree of the root node.
    public var minimumDegree: Int { self.root.minimumDegree }
    
    /// Location this B-Tree is stored on disk
    public var storagePath: URL
    
    /// the root node of the B-Tree
    private var root: BTreeNode<Key, Value>
    
    /// Storage engine used by this B-Tree
    private var storage: Storage<Key, Value>
    
    // MARK: Setup & Deconstruction
    
    /// Set up B-Tree
    ///
    /// - parameter storagePath: Location this B-Tree is stored on disk
    /// - parameter minimumDegree: Optional. The minimum degree of this B-Tree. See README for information.
    public init(storagePath: URL, minimumDegree: Int = 4096) throws {
        self.storagePath = storagePath
        self.storage = try Storage(path: storagePath)
        
        if self.storage.isEmpty() {
            self.root = BTreeNode(minimumDegree: minimumDegree, isRoot: true, isLoaded: true, storage: self.storage)
            
            try self.root.save()
        } else {
            self.root = try self.storage.readRootNode()
            self.root.storage = self.storage
        }
    }
    
    // MARK: Operations
    
    /// Convenience. Find the provided key within the B-Tree. Exactly the same as searching on the root node.
    ///
    /// - parameter key: Key to find within the B-Tree.
    /// - returns: Value that matches this key.
    /// - throws: `BTreeError.unableToLoadNode` if unable to load any nodes used in this search.
    public func find(_ key: Key) throws -> Value? {
        try self.root.find(key)
    }
    
    /// Insert an element into the B-Tree.
    ///
    /// - parameter newElement: `BTreeElement`  to insert into the B-Tree
    /// - Throws: `BTreeError.unableToInsert` if not able to insert given element
    public func insert(_ newElement: BTreeElement<Key, Value>) throws {
        if self.root.isFull {
            var root = self.root
            
            self.root = BTreeNode(
                minimumDegree: root.minimumDegree,
                isRoot: true,
                isLoaded: true,
                storage: self.storage
            )
            root.isRoot = false
            
            self.root.children.append(root)
            
            try self.root.split(at: 0)
        }
        
        try self.root.insertNonFull(newElement)

        try self.storage.copy()
    }
}
