//
//  Storage.swift
//
//
//  Created by Emma K Alexandra on 7/4/19.
//
import Foundation

/// Storage Engine
public class Storage<Key: Comparable & Codable, Value: Codable> {

    // MARK: Properties

    /// Path to store B-Tree on disk
    public var path: URL

    /// File the B-Tree is stored  in
    private var file: FileHandle

    private var writeFilePath: URL

    private var writeFile: FileHandle? = nil

    private let isReadOnly: Bool

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
    public init(path: URL, isReadOnly: Bool = false) throws {
        self.path = path
        self.writeFilePath = URL(string: "\(path.absoluteString).tmp")!
        self.isReadOnly = isReadOnly

        // Load storage file, if it exists
        do {
            if self.isReadOnly {
                self.file = try FileHandle(forReadingFrom: self.path)

            } else {
                self.file = try FileHandle(forUpdating: self.path)

                try "".write(to: self.writeFilePath, atomically: false, encoding: .utf8)
                self.writeFile = try FileHandle(forUpdating: self.writeFilePath)
            }
        } catch {
            // Create new storage file if no storage file exists at given path
            if self.isReadOnly {
                throw BTreeError.storageMarkedReadOnly
            }

            do {
                try "".write(to: self.path, atomically: false, encoding: .utf8)
                self.file = try FileHandle(forUpdating: self.path)

                try "".write(to: self.writeFilePath, atomically: false, encoding: .utf8)
                self.writeFile = try FileHandle(forUpdating: self.writeFilePath)
            } catch {
                throw BTreeError.unableToCreateStorage
            }
        }

        self.recordDelimiterAsData = self.recordDelimiter.data(using: .utf8)!

        if !self.isReadOnly {
            self.initialize()
        }
    }

    /// Close the storage file on deinit
    deinit {
        self.close()

        if let _ = self.writeFile {
            try? FileManager.default.removeItem(at: self.writeFilePath)
        }
    }

    // MARK: Operations

    private func initialize() {
        let zeroes = 0.toPaddedString() + self.recordDelimiter
        self.writeFile!.seek(toFileOffset: 0)
        self.writeFile!.write(zeroes.data(using: .utf8)!)

    }

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
        guard let writeFile = self.writeFile else {
            throw BTreeError.storageMarkedReadOnly
        }

        let offset = try self.append(node)

        writeFile.seek(toFileOffset: 0)

        let offsetWithLeadingZeroes = offset.toPaddedString()
        writeFile.write(offsetWithLeadingZeroes.data(using: .utf8)!)

        return offset
    }

    /// Read the current root from disk
    ///
    /// - returns: The root node
    /// - throws: If storage is corrupted, if root record is corrupted
    public func readRootNode() throws -> BTreeNode<Key, Value> {
        if !(isReadOnly || self.writeFileIsEmpty) {
            try self.copy()
        }

        self.file.seek(toFileOffset: 0)

        let rootRecordOffsetData = self.file.readData(ofLength: rootRecordPointerSize)
                
        guard let rootRecordOffsetString = String(data: rootRecordOffsetData, encoding: .utf8) else {
            throw BTreeError.invalidRecordSize
        }
        
        guard let rootRecordOffset = UInt64(rootRecordOffsetString) else {
            throw BTreeError.invalidRecordSize
        }

        do {
            var rootNode = try self.findNode(withOffset: rootRecordOffset)
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
        let nodeData: Data?

        do {
            self.file.seek(toFileOffset: offset)

            let recordSizeData = self.file.readData(ofLength: lengthOfRecordSize)

            guard let recordSizeString = String(data: recordSizeData, encoding: .utf8) else {
                throw BTreeError.invalidRecordSize
            }

            guard let recordSize = Int(recordSizeString) else {
                throw BTreeError.invalidRecordSize
            }

            nodeData = self.file.readData(ofLength: recordSize)
        } catch {
            if self.isReadOnly {
                nodeData = nil
            } else if let writeFile = self.writeFile {
                writeFile.seek(toFileOffset: offset)

                let recordSizeData = writeFile.readData(ofLength: lengthOfRecordSize)

                guard let recordSizeString = String(data: recordSizeData, encoding: .utf8) else {
                    throw BTreeError.invalidRecordSize
                }

                guard let recordSize = Int(recordSizeString) else {
                    throw BTreeError.invalidRecordSize
                }

                nodeData = writeFile.readData(ofLength: recordSize)
            } else {
                nodeData = nil
            }
        }

        guard let actualNodeData = nodeData else {
            throw BTreeError.invalidRecord
        }

        do {
            var node = try self.decoder.decode(BTreeNode<Key, Value>.self, from: actualNodeData)
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

        guard let writeFile = self.writeFile else {
            throw BTreeError.storageMarkedReadOnly
        }

        let nodeOffset = writeFile.seekToEndOfFile()

        let encodedNode = try self.encoder.encode(node)
        
        var dataToWrite = Data()
        dataToWrite.append(encodedNode.count.toPaddedString().data(using: .utf8)!)
        dataToWrite.append(encodedNode)
        dataToWrite.append(self.recordDelimiterAsData)

        writeFile.write(dataToWrite)

        return nodeOffset
    }
}

extension Storage {
    func copy() throws {
        try FileManager.default.removeItem(at: self.path)
        try FileManager.default.copyItem(at: self.writeFilePath, to: self.path)
        try FileManager.default.removeItem(at: self.writeFilePath)

        self.file = try FileHandle(forUpdating: self.path)

        try "".write(to: self.writeFilePath, atomically: false, encoding: .utf8)
        self.writeFile = try FileHandle(forUpdating: self.writeFilePath)
        self.initialize()
    }

    var writeFileIsEmpty: Bool {
        !self.isReadOnly && self.writeFile!.offsetInFile == 20
    }
}
