//
//  BTree.swift
//
//
//  Created by Emma Foster on 7/4/19.
import Foundation

/// Main implementation of a B-Tree
public class BTree<Key: Comparable & Codable, Value: Codable> {
    
    // MARK: Properties
    
    /// the root node of the B-Tree
    var root: BTreeNode<Key, Value>
    
    /// Convenience. Pass through for te minimum degree of the root node.
    public var minimumDegree: Int { self.root.minimumDegree }
    
    /// Location this B-Tree is stored on disk
    public var storagePath: URL
    
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
            self.root = BTreeNode<Key, Value>(minimumDegree: minimumDegree, isLeaf: true, storage: self.storage)
            self.root.id = UUID()
            self.root.isLoaded = true
            try self.storage.saveRoot(self.root)
            
        } else {
            self.root = try self.storage.readRootNode()
            self.root.storage = self.storage
            
        }
        
    }
    
    /// Make sure to close our storage.
    deinit {
        self.storage.close()
        
    }
    
    // MARK: Operations
    
    /// Convenience. Find the provided key within the B-Tree. Exactly the same as searching on the root node.
    ///
    /// - parameter key: Key to find within the B-Tree.
    /// - returns: Value that matches this key.
    /// - throws: `BTreeError.unableToLoadNode` if unable to load any nodes used in this search.
    public func find(_ key: Key) throws -> Value? {
        return try self.root.find(key)
        
    }
    
    /// Insert an element into the B-Tree.
    ///
    /// - parameter newElement: `BTreeElement`  to insert into the B-Tree
    /// - Throws: `BTreeError.unableToInsert` if not able to insert given element
    public func insert(_ newElement: BTreeElement<Key, Value>) throws {
        let root = self.root
        
        if root.isFull {
            let newRoot = BTreeNode<Key, Value>(minimumDegree: root.minimumDegree, isLeaf: false, storage: self.storage)
            newRoot.id = UUID()
            newRoot.isLoaded = true
            
            self.root = newRoot
            
            newRoot.children.append(root)
            
            try self.storage.saveRoot(newRoot)
            
            do {
                try newRoot.split(at: 0)
                try newRoot.insertNonFull(newElement)
                
            } catch {
                throw BTreeError.unableToInsert
                
            }
            
        } else {
            do {
                try root.insertNonFull(newElement)
                
            } catch {
                throw BTreeError.unableToInsert
                
            }
            
        }
        
    }
    
}

/// A node in the B-Tree
public final class BTreeNode<Key: Comparable & Codable, Value: Codable>: Codable {
    
    // MARK: Properties
    
    typealias Hatchimals = Hashable // my wife made me do this
    
    /// The elements in this node
    public var elements = [BTreeElement<Key, Value>]()
    
    /// The children nodes of this node
    public var children = [BTreeNode<Key, Value>]()
    
    /// The minimum degree of this node. See README for details.
    public var minimumDegree: Int
    
    /// If this node is a leaf
    public var isLeaf: Bool
    
    /// If this node is full of elements.
    public var isFull: Bool { self.elements.count == (2 * self.minimumDegree - 1) }
    
    /// The id of this node. Used in storage.
    public var id: UUID? = nil
    
    /// If this node's elements and children are loaded from disk.
    public var isLoaded = false
    
    /// The storage engine used by this node.
    unowned var storage: Storage<Key, Value>? = nil
    
    /// We only want to serialize a few fields from this node.
    enum CodingKeys: String, CodingKey {
        case elements
        case children
        case minimumDegree
        case isLeaf
        case id
    }
    
    // MARK: Creation
    
    /// Initializer used to load this node from disk.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.elements = try values.decode(Array<BTreeElement<Key, Value>>.self, forKey: .elements)
        
        self.minimumDegree = try values.decode(Int.self, forKey: .minimumDegree)
        self.isLeaf = try values.decode(Bool.self, forKey: .isLeaf)
        
        let decodedChildren = try values.decode([String].self, forKey: .children)
        
        self.children = decodedChildren.map({ (childId) -> BTreeNode<Key, Value> in
            let child = BTreeNode(minimumDegree: self.minimumDegree, isLeaf: self.isLeaf)
            child.id = UUID(uuidString: childId)
            
            return child
            
        })
        
        self.id = UUID(uuidString: try values.decode(String.self, forKey: .id))
        
        self.isLoaded = true
        
    }
    
    /// Set up a new node
    ///
    /// - parameter minimumDegree: The minimum degree of this node. See README for details.
    /// - parameter isLeaf: If this node is a leaf
    /// - parameter storage: The storage engine used by this node.
    public init(minimumDegree: Int, isLeaf: Bool, storage: Storage<Key, Value>? = nil) {
        self.minimumDegree = minimumDegree
        self.isLeaf = isLeaf
        self.storage = storage
        
    }
    
    // MARK: Operations
    
    /// Find a key in this node
    ///
    /// - parameter key: Key to find in this node
    /// - returns: Value matching the given key
    /// - throws: `BTreeError.unableToLoadNode` if unable to load any nodes from disk used for this find.
    public func find(_ key: Key) throws -> Value? {
        var i = 0
        
        while i < self.elements.count, key > self.elements[i].key {
            i += 1
            
        }
        
        if i < self.elements.count, key == self.elements[i].key {
            return self.elements[i].value
            
        } else if self.isLeaf {
            return nil
            
        } else {
            do {
                try self.children[i].load()
                
            } catch {
                return nil
                
            }
            
            return try self.children[i].find(key)
            
        }
        
    }
    
    /// Inserts an element in to this node, if the node is not full.
    ///
    /// - parameter newElement: Element to insert into this node
    /// - throws: `BTreeError.unableToLoadNode` if unable to load any nodes used in this insert
    public func insertNonFull(_ newElement: BTreeElement<Key, Value>) throws {
        if !self.isLoaded {
            do {
                try self.load()
                
            } catch {
                throw BTreeError.unableToLoadNode
                
            }
            
        }
        
        var i = self.elements.count - 1
        
        if self.isLeaf {
            while i > 0, newElement.key < self.elements[i].key {
                i -= 1
                
            }
            
            self.elements.insert(newElement, at: i + 1)
            try self.save()
            
        } else {
            while i > 0, newElement.key < self.elements[i].key {
                i -= 1
                
            }
            
            i += 1
            
            self.children[i].storage = self.storage
            
            try self.children[i].load()
            if self.children[i].isFull {
                try self.split(at: i)
                if newElement.key > self.elements[i].key {
                    i += 1
                    
                }
                
            }
            
            try self.children[i].insertNonFull(newElement)
            
        }
        
    }
    
    /// Splits the given child of this node.
    ///
    /// - parameter childIndex: The index of the child to split
    /// - throws: If unable to load any nodes used in this split, or if storage engine is unable to write to disk.
    public func split(at childIndex: Int) throws {
        let childToSplit = self.children[childIndex]
        
        let newChild = BTreeNode(minimumDegree: self.minimumDegree, isLeaf: childToSplit.isLeaf, storage: self.storage!)
        
        newChild.elements = Array(childToSplit.elements[(self.minimumDegree - 1)..<(2 * self.minimumDegree - 2)])
        newChild.id = UUID()
        newChild.isLoaded = true

        
        if !childToSplit.isLeaf {
            newChild.children = Array(childToSplit.children[self.minimumDegree...(2 * self.minimumDegree - 1)])
            
        }
        
        self.children.insert(newChild, at: childIndex + 1)
        
        self.elements.insert(childToSplit.elements[self.minimumDegree], at: childIndex)
        
        try childToSplit.save()
        try newChild.save()
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
        try container.encode(self.children.map { $0.id! }, forKey: .children)
        try container.encode(self.minimumDegree, forKey: .minimumDegree)
        try container.encode(self.isLeaf, forKey: .isLeaf)
        try container.encode(self.id, forKey: .id)
        
    }
    
    /// Save this node to disk using storage engine
    ///
    /// - throws: If unable to load this node, or if storage engine is unable to write to disk
    public func save() throws {
        guard self.isLoaded else {
            throw BTreeError.nodeIsNotLoaded
            
        }
        
        try self.storage?.upsert(self)
        
    }
    
    /// Loads this node from disk using storage engine
    ///
    /// - throws: If unable to load node
    public func load() throws {
        guard let storage = self.storage, let id = self.id else {
            throw BTreeError.unableToLoadNode
            
        }
        
        do {
            let possibleNode = try storage.findNode(withId: id.uuidString)
            
            if let node = possibleNode {
                self.elements = node.elements
                self.children = node.children
                self.isLeaf = node.isLeaf
                self.minimumDegree = node.minimumDegree
                
                self.isLoaded = true
                
            }
            
        } catch {
            throw BTreeError.unableToLoadNode
            
        }
        
    }
    
}

// MARK: BTreeElement

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

// MARK: Utilities and Errors

/// Helper to avoid passing encoders and decoders down to all nodes
struct BTreeHelper {
    /// Encoder to convert nodes to JSON
    static let encoder = JSONEncoder()
    
    /// Decoder to convert JSON to node
    static let decoder = JSONDecoder()
    
}


/// All possible errors that can occur between the B-Tree and the storage engine
enum BTreeError: Error {
    case unableToInsert
    case nodeIsNotLoaded
    case unableToLoadNode
    case unableToReadDatabase
    case unableToCreateDatabase
    case unableToModifyTemporaryDatabase
    case unableToRenameTemporaryDatabase
    case invalidDatabase
    case invalidRootRecord
    case invalidRecord
}


/// Extension to UUID to convert to data
extension UUID {
    var data: Data {
        return withUnsafeBytes(of: self.uuid, { Data($0) })
        
    }
    
}
