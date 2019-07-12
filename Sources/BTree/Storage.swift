//
//  Storage.swift
//  
//
//  Created by Emma Foster on 7/4/19.
//
import Foundation

/// Storage Engine
public class Storage<Key: Comparable & Codable, Value: Codable> {
    
    // MARK: Properties
    
    /// Path to store B-Tree on disk
    public var path: URL
    
    /// File the B-Tree is stored  in
    private var file: FileHandle
    
    // TODO: Make these init parameters
    /// Amount to read from disk at a time
    private let chunkSize = 4096
    
    /// Delimiter records are split by on disk
    private let recordDelimiter = "\n"
    private let recordDelimiterAsData: Data
    
    /// Delimiter ids are split by on disk
    private let idDelimiter = ";"
    private let idDelimiterAsData: Data
    
    /// The encoding to use on disk
    private let encoding = String.Encoding.utf8
    
    // MARK: Construction & Deconstruction
    
    /// Setups up this storage engine. Creates a new DB if one is not current at the given location.
    ///
    /// - parameter path: Location on disk to store a B-Tree.
    /// - throws: `BTreeError.unableToCreateDatabase` if unable to write to disk
    public init(path: URL) throws {
        self.path = path
        
        // Load DB, if it exists
        do {
            self.file = try FileHandle(forUpdating: path)
            
        } catch {
            // Create new DB if no DB exists at given path
            do {
                try "".write(to: path, atomically: true, encoding: .utf8)
                self.file = try FileHandle(forUpdating: path)
                
            } catch {
                throw BTreeError.unableToCreateDatabase
                
            }
            
        }
        
        self.recordDelimiterAsData = self.recordDelimiter.data(using: .utf8)!
        self.idDelimiterAsData = self.idDelimiter.data(using: .utf8)!
        
    }
    
    /// Close the database file on deinit
    deinit {
        self.close()
        
    }
    
    // MARK: Operations
    
    /// If the storage currently used is empty
    ///
    /// - returns: `Bool`
    public func isEmpty() -> Bool {
        return self.file.seekToEndOfFile() == 0
        
    }
    
    /// Wrap up operations.
    public func close() {
        self.file.closeFile()
        
    }
    
    /// Save a new root to disk
    ///
    /// - parameter node: Node to store as new root
    /// - throws: If unable to load the given node, or unable to write to disk
    public func saveRoot(_ node: BTreeNode<Key, Value>) throws -> Int {
        if !node.isLoaded {
            throw BTreeError.nodeIsNotLoaded
            
        }
        
        if self.isEmpty() {
            let zeroes = String(format: "%016d\n", 0)
            self.file.write(zeroes.data(using: .utf8)!)
            
        }
        
        let offset = try self.append(node)
        
        self.file.seek(toFileOffset: 0)
        
        let offsetWithLeadingZeroes = String(format: "%016d\n", offset)
        self.file.write(offsetWithLeadingZeroes.data(using: .utf8)!)
        
        return offset
        
    }
    
    /// Read the current root from disk
    ///
    /// - returns: The root node
    /// - throws: If database is corrupted, if root record is corrupted
    public func readRootNode() throws -> BTreeNode<Key, Value> {
        self.file.seek(toFileOffset: 0)
        
        let buffer = self.file.readData(ofLength: 17)
        let offsetData = buffer.subdata(in: 0..<buffer.firstIndex(of: "\n".data(using: .utf8)!.bytes[0])!)
        let maybeOffset = Int(String(data: offsetData, encoding: .utf8)!)
        
        guard let offset = maybeOffset else {
            throw BTreeError.invalidDatabase
            
        }
        
        do {
            let rootNode = try self.findNode(withOffset: offset)
            rootNode.offset = offset
            return rootNode
            
        } catch {
            throw BTreeError.invalidRootRecord
            
        }
        
        
    }
    
    /// Finds a node on disk
    ///
    /// - parameter offset: The offset of the node w want to retrieve on disk
    /// - returns: The node, if it found on disk. Otherwise, nil
    /// - throws: If record is corrupted
    public func findNode(withOffset offset: Int) throws -> BTreeNode<Key, Value> {
        self.file.seek(toFileOffset: UInt64(offset))
        
        var buffer = Data()
        
        while buffer.firstIndex(of: "\n".data(using: .utf8)!.bytes[0]) == nil {
            buffer.append(self.file.readData(ofLength: self.chunkSize))
            
        }
        
        let nodeData = buffer.subdata(in: 0..<buffer.firstIndex(of: "\n".data(using: .utf8)!.bytes[0])!)
        
        do {
            let node = try BTreeHelper.decoder.decode(BTreeNode<Key, Value>.self, from: nodeData)
            node.storage = self
            node.offset = offset
            
            return node
            
        } catch {
            throw BTreeError.invalidRecord
            
        }
        
    }
    
    /// Append a node to the current database
    ///
    /// - parameter node: Node to append to the current database
    /// - throws: If unable to load the given node
    func append(_ node: BTreeNode<Key, Value>) throws -> Int {
        if !node.isLoaded {
            throw BTreeError.nodeIsNotLoaded
            
        }
        
        let endOfFile = self.file.seekToEndOfFile()
        
        var dataToWrite = Data()
        dataToWrite.append(try BTreeHelper.encoder.encode(node))
        dataToWrite.append(self.recordDelimiterAsData)
        
        self.file.write(dataToWrite)
        
        return Int(endOfFile)
        
    }
    
}

extension Data {
    var bytes : [UInt8]{
        return [UInt8](self)
    }
}
