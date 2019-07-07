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
    public func saveRoot(_ node: BTreeNode<Key, Value>) throws {
        guard let populatedId = node.id?.uuidString.data(using: .utf8) else {
            throw BTreeError.nodeIsNotLoaded
            
        }
        
        self.file.seek(toFileOffset: 0)
        self.file.write("root".data(using: .utf8)!)
        self.file.write(populatedId)
        self.file.write(self.recordDelimiterAsData)
        try self.upsert(node)
        
    }
    
    /// Read the current root from disk
    ///
    /// - returns: The root node
    /// - throws: If database is corrupted, if root record is corrupted
    public func readRootNode() throws -> BTreeNode<Key, Value> {
        self.file.seek(toFileOffset: 0)
        
        let firstLineData = self.file.readData(ofLength: 40) // root + UUID
        guard let firstLine = String(bytes: firstLineData, encoding: .utf8) else {
            throw BTreeError.invalidDatabase
            
        }
        
        guard let indexOfT = firstLine.firstIndex(of: "t") else { // "root" ends
            throw BTreeError.invalidDatabase
            
        }
        
        let indexOfUUID = firstLine.index(after: indexOfT)
        
        let rootUUID = firstLine[indexOfUUID...]
        
        guard let rootNode = try self.findNode(withId: String(rootUUID)) else {
            throw BTreeError.invalidRootRecord
            
        }
        
        return rootNode
        
    }
    
    /// Finds a node on disk
    ///
    /// - parameter id: The id of the node to find on disk
    /// - returns: The node, if it found on disk. Otherwise, nil
    /// - throws: If record is corrupted
    public func findNode(withId id: String) throws -> BTreeNode<Key, Value>? {
        guard let recordRange = self.findRecord(id) else {
            return nil
            
        }
        
        self.file.seek(toFileOffset: UInt64(recordRange.lowerBound))
        let recordData = self.file.readData(ofLength: recordRange.count)
        
        do {
            let node = try BTreeHelper.decoder.decode(BTreeNode<Key, Value>.self, from: recordData)
            node.storage = self
            
            return node
            
        } catch {
            throw BTreeError.invalidRecord
            
        }
        
    }
    
    /// Inserts or updates the given node on disk
    ///
    /// - parameter node: The node to insert or update
    /// - throws: If unable to load the given node, or unable to write to disk
    public func upsert(_ node: BTreeNode<Key, Value>) throws {
        guard let populatedId = node.id else {
            throw BTreeError.nodeIsNotLoaded
            
        }
        
        if let recordLocation = self.findRecord(populatedId.uuidString) {
            var newFilePath = self.path
            let lastComponent = newFilePath.lastPathComponent
            newFilePath.deleteLastPathComponent()
            newFilePath.appendPathComponent(".\(lastComponent)")
            
            try? FileManager.default.removeItem(at: newFilePath)
            try "".write(to: newFilePath, atomically: true, encoding: .utf8)
            let newFile = try FileHandle(forUpdating: newFilePath)

            do {
                self.transfer(from: self.file, to: newFile, in: 0..<recordLocation.lowerBound)
                newFile.seek(toFileOffset: newFile.offsetInFile)
                newFile.write(try BTreeHelper.encoder.encode(node))
                newFile.write(self.recordDelimiterAsData)
                
                let endOfFile = self.file.seekToEndOfFile()
                if endOfFile > recordLocation.upperBound {
                    self.transfer(from: self.file, to: newFile, in: recordLocation.upperBound..<Int(endOfFile))
                    
                }
                
                
                
            } catch {
                throw BTreeError.unableToModifyTemporaryDatabase
                
            }
            
            
            do {
                try FileManager.default.removeItem(at: self.path)
                try FileManager.default.moveItem(at: newFilePath, to: self.path)
                self.file = newFile
                
            } catch {
                throw BTreeError.unableToRenameTemporaryDatabase
                
            }

        } else {
            try self.append(node)
            
        }
        
    }
    
    /// Transfers the given range from one file to another
    ///
    /// - parameter from: The file to read from
    /// - parameter to: The file the write to
    /// - parameter in: The range of `from` to transfer
    func transfer(from file: FileHandle, to destinationFile: FileHandle, in range: Range<Int>) {
        file.seek(toFileOffset: UInt64(range.lowerBound))
        var buffer = Data(capacity: self.chunkSize)
        
        while Int(file.offsetInFile) + self.chunkSize < range.upperBound {
            buffer.append(file.readData(ofLength: self.chunkSize))
            destinationFile.write(buffer)
            buffer = Data(capacity: self.chunkSize)
            
        }
        
        let readData = file.readData(ofLength: range.upperBound - Int(file.offsetInFile))
        buffer.append(readData)
        destinationFile.write(buffer)
        
    }
    
    /// Append a node to the current database
    ///
    /// - parameter node: Node to append to the current database
    /// - throws: If unable to load the given node
    func append(_ node: BTreeNode<Key, Value>) throws {
        guard let populatedId = node.id?.uuidString.data(using: .utf8) else {
            throw BTreeError.nodeIsNotLoaded
            
        }
        
        self.file.seekToEndOfFile()
        
        var dataToWrite = Data()
        dataToWrite.append(populatedId)
        dataToWrite.append(self.idDelimiterAsData)
        dataToWrite.append(try BTreeHelper.encoder.encode(node))
        dataToWrite.append(self.recordDelimiterAsData)
        
        self.file.write(dataToWrite)
        
    }
    
    /// Find the range of the given record within the database
    ///
    /// - parameter id: The id of the record we want to find
    /// - returns: Range of the given record within the database, if found. Otherwise, nil.
    func findRecord(_ id: String) -> Range<Int>? {
        self.file.seek(toFileOffset: 41) // root + root node's id + \n
        var buffer = Data(capacity: self.chunkSize)
        var bufferOffset = 41 // root + root node's id + \n
        var atEOF = false
        
        while !atEOF {
            while let idEndIndex = buffer.firstIndex(where: { $0 == self.idDelimiterAsData.first }), let recordEndIndex = buffer.firstIndex(where: { $0 == self.recordDelimiterAsData.first }) {
                let readId = String(data: buffer.subdata(in: 0..<idEndIndex), encoding: .utf8)
                
                if readId == id {
                    buffer.removeSubrange(0..<idEndIndex + 1)
                    bufferOffset += idEndIndex + 1
                    
                    return (bufferOffset)..<(bufferOffset + recordEndIndex - idEndIndex)
                    
                } else {
                    buffer.removeSubrange(0..<recordEndIndex + 1)
                    bufferOffset += recordEndIndex + 1
                    
                }
                
            }
            
            let temporaryData = self.file.readData(ofLength: self.chunkSize)

            if temporaryData.isEmpty {
                atEOF = true
                
            } else {
                buffer.append(temporaryData)
                
            }
            
        }
        
        return nil
        
    }
    
}
