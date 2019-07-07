import Foundation

public class BTree<Key: Comparable & Codable, Value: Codable> {
    var root: BTreeNode<Key, Value>
    
    public var minimumDegree: Int { self.root.minimumDegree }
    
    public var storagePath: URL
    
    private var storage: Storage<Key, Value>
    
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
    
    deinit {
        self.storage.close()
        
    }
    
    public func find(_ key: Key) throws -> Value? {
        return try self.root.find(key)
        
    }
    
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

public final class BTreeNode<Key: Comparable & Codable, Value: Codable>: Codable {
    typealias Hatchimals = Hashable // my wife made me do this
    
    public var elements = [BTreeElement<Key, Value>]()
    public var children = [BTreeNode<Key, Value>]()
    
    public var minimumDegree: Int
    public var isLeaf: Bool
    
    public var isFull: Bool { self.elements.count == (2 * self.minimumDegree - 1) }
    
    public var id: UUID? = nil
    public var isLoaded = false
    
    unowned var storage: Storage<Key, Value>? = nil
    
    enum CodingKeys: String, CodingKey {
        case elements
        case children
        case minimumDegree
        case isLeaf
        case id
    }
    
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
    
    public init(minimumDegree: Int, isLeaf: Bool, storage: Storage<Key, Value>? = nil) {
        self.minimumDegree = minimumDegree
        self.isLeaf = isLeaf
        self.storage = storage
        
    }
    
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.elements, forKey: .elements)
        try container.encode(self.children.map { $0.id! }, forKey: .children)
        try container.encode(self.minimumDegree, forKey: .minimumDegree)
        try container.encode(self.isLeaf, forKey: .isLeaf)
        try container.encode(self.id, forKey: .id)
        
    }
    
    public func save() throws {
        guard self.isLoaded else {
            throw BTreeError.nodeIsNotLoaded
            
        }
        
        try self.storage?.upsert(self)
        
    }
    
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

public struct BTreeElement<Key: Comparable & Codable, Value: Codable>: Codable {
    let key: Key
    let value: Value
    
}

struct BTreeHelper {
    static let encoder = JSONEncoder()
    static let decoder = JSONDecoder()
    
}

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

extension UUID {
    var data: Data {
        return withUnsafeBytes(of: self.uuid, { Data($0) })
        
    }
    
}
