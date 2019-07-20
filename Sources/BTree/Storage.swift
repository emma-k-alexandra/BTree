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

    /// Delimiter records are split by on disk
    private let recordDelimiter = "\n"
    private let recordDelimiterAsData: Data
    
    /// Offset in storage where records begin
    private let startOfRecords = 21
    
    /// The length in bytes of the root record pointer
    private let rootRecordPointerSize = 19
    
    /// The length in bytes of a record size
    private let lengthOfRecordSize = 19

    /// The encoding to use on disk
    private let encoding = String.Encoding.utf8

    /// Encode JSON to disk
    private let encoder = JSONEncoder()

    /// Decode JSON from disk
    private let decoder = JSONDecoder()

    // MARK: Construction & Deconstruction

    /// Setups up this storage engine. Creates a new storage file if one is not current at the given location.
    ///
    /// - parameter path: Location on disk to store a B-Tree.
    /// - throws: `BTreeError.unableToCreateStorage` if unable to write to disk
    public init(path: URL) throws {
        self.path = path

        // Load storage file, if it exists
        do {
            self.file = try FileHandle(forUpdating: path)

        } catch {
            // Create new storage file if no storage file exists at given path
            do {
                try "".write(to: path, atomically: true, encoding: .utf8)
                self.file = try FileHandle(forUpdating: path)

            } catch {
                throw BTreeError.unableToCreateStorage

            }

        }

        self.recordDelimiterAsData = self.recordDelimiter.data(using: .utf8)!

    }

    /// Close the storage file on deinit
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
    /// - returns: The offset of the root node in storage
    /// - throws: If unable to load the given node, or unable to write to disk
    public func saveRoot(_ node: BTreeNode<Key, Value>) throws -> UInt64 {
        if !node.isLoaded {
            throw BTreeError.nodeIsNotLoaded

        }

        if self.isEmpty() {
            let zeroes = 0.toPaddedString() + self.recordDelimiter
            self.file.write(zeroes.data(using: .utf8)!)

        }

        let offset = try self.append(node)

        self.file.seek(toFileOffset: 0)

        let offsetWithLeadingZeroes = offset.toPaddedString()
        self.file.write(offsetWithLeadingZeroes.data(using: .utf8)!)

        return offset

    }

    /// Read the current root from disk
    ///
    /// - returns: The root node
    /// - throws: If storage is corrupted, if root record is corrupted
    public func readRootNode() throws -> BTreeNode<Key, Value> {
        self.file.seek(toFileOffset: 0)

        let rootRecordOffsetData = self.file.readData(ofLength: rootRecordPointerSize)
                
        guard let rootRecordOffsetString = String(data: rootRecordOffsetData, encoding: .utf8) else {
            throw BTreeError.invalidRecordSize
            
        }
        
        guard let rootRecordOffset = UInt64(rootRecordOffsetString) else {
            throw BTreeError.invalidRecordSize
            
        }

        do {
            let rootNode = try self.findNode(withOffset: rootRecordOffset)
            rootNode.offset = rootRecordOffset
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
    public func findNode(withOffset offset: UInt64) throws -> BTreeNode<Key, Value> {
        self.file.seek(toFileOffset: offset)
        
        let recordSizeData = self.file.readData(ofLength: lengthOfRecordSize)
        
        guard let recordSizeString = String(data: recordSizeData, encoding: .utf8) else {
            throw BTreeError.invalidRecordSize
            
        }
        
        guard let recordSize = Int(recordSizeString) else {
            throw BTreeError.invalidRecordSize
            
        }
        
        let nodeData = self.file.readData(ofLength: recordSize)

        do {
            let node = try self.decoder.decode(BTreeNode<Key, Value>.self, from: nodeData)
            node.storage = self
            node.offset = offset

            return node

        } catch {
            throw BTreeError.invalidRecord

        }

    }

    /// Append a node to the current storage
    ///
    /// - parameter node: Node to append to the current storage
    /// - returns: The offset of the provided node in storage
    /// - throws: If unable to load the given node
    func append(_ node: BTreeNode<Key, Value>) throws -> UInt64 {
        if !node.isLoaded {
            throw BTreeError.nodeIsNotLoaded

        }

        let endOfFile = self.file.seekToEndOfFile()

        let encodedNode = try self.encoder.encode(node)
        
        var dataToWrite = Data()
        dataToWrite.append(encodedNode.count.toPaddedString().data(using: .utf8)!)
        dataToWrite.append(encodedNode)
        dataToWrite.append(self.recordDelimiterAsData)

        self.file.write(dataToWrite)

        return endOfFile

    }

}

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
