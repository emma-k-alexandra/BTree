import XCTest
@testable import BTree

@available(OSX 10.12, *)
final class BTreeTests: XCTestCase {
    
    // MARK: Test structures
    
    struct TestKey: Comparable & Codable {
        static func < (lhs: BTreeTests.TestKey, rhs: BTreeTests.TestKey) -> Bool {
            return lhs.id < rhs.id
            
        }
        
        let id: Int
        
    }
    
    struct TestValue: Codable {
        let value: String
        
    }
    
    // MARK: BTreeElement Tests
    
    func testBTreeElementInit() {
        let key = TestKey(id: 0)
        let value = TestValue(value: "A")
        
        let element = BTreeElement<TestKey, TestValue>(key: key, value: value)
        
        XCTAssertEqual(key, element.key)
        XCTAssertEqual(value.value, element.value.value)
        
    }
    
    // MARK: BTreeNode Test
    
    func testBTreeNodeInit() {
        var storagePath = FileManager.default.temporaryDirectory
        storagePath.appendPathComponent("testBTreeNodeInit.db")
        
        let storage = try! Storage<TestKey, TestValue>(path: storagePath)
        let node = BTreeNode<TestKey, TestValue>(minimumDegree: 2, isLeaf: true, storage: storage)
        
        XCTAssertEqual(node.minimumDegree, 2)
        XCTAssertEqual(node.isLeaf, true)
        XCTAssertEqual(storage.path, node.storage?.path)
        
        try? FileManager.default.removeItem(at: storagePath)
        
    }
    
    func testBTreeNodeFind() {
        var storagePath = FileManager.default.temporaryDirectory
        storagePath.appendPathComponent("testBTreeNodeInit.db")
        
        let storage = try! Storage<TestKey, TestValue>(path: storagePath)
        let node = BTreeNode<TestKey, TestValue>(minimumDegree: 2, isLeaf: true, storage: storage)
        node.isLoaded = true
        
        let offset = try! storage.saveRoot(node)
        node.offset = offset
        
        try! node.load()
        
        let key = TestKey(id: 0)
        let value = TestValue(value: "A")
        
        let element = BTreeElement<TestKey, TestValue>(key: key, value: value)
        
        try! node.insertNonFull(element)
        
        let foundElement = try! node.find(element.key)
        
        XCTAssertEqual(foundElement?.value, element.value.value)
        
        try? FileManager.default.removeItem(at: storagePath)
        
    }
    
    // MARK: BTree Tests
    
    func testBTreeInit() {
        var tempDirectory = FileManager.default.temporaryDirectory
        tempDirectory.appendPathComponent("initTest.db")
        
        let tree = try! BTree<TestKey, TestValue>(storagePath: tempDirectory)
        
        XCTAssertEqual(tree.storagePath, tempDirectory)
        
    }
    
    func testBTreeBasicInsert() {
        var tempDirectory = FileManager.default.temporaryDirectory
        tempDirectory.appendPathComponent("testBTreeBasicInsert.db")
        
        let tree = try! BTree<TestKey, TestValue>(storagePath: tempDirectory)
        
        let element = BTreeElement(key: TestKey(id: 0), value: TestValue(value: "A"))
        
        try! tree.insert(element)
        
        try? FileManager.default.removeItem(at: tempDirectory)
        
    }
    
    func testBTreeBasicFind() {
        var tempDirectory = FileManager.default.temporaryDirectory
        tempDirectory.appendPathComponent("testBTreeBasicInsert.db")
        
        let tree = try! BTree<TestKey, TestValue>(storagePath: tempDirectory)
        let element = BTreeElement(key: TestKey(id: 0), value: TestValue(value: "A"))
        
        try! tree.insert(element)
        
        XCTAssertEqual(try! tree.find(element.key)?.value, element.value.value)
        
        try? FileManager.default.removeItem(at: tempDirectory)
        
    }
    
    func testBTreeMultiInsert() {
        var tempDirectory = FileManager.default.temporaryDirectory
        tempDirectory.appendPathComponent("testBTreeMultiInsert.db")
        
        let tree = try! BTree<TestKey, TestValue>(storagePath: tempDirectory, minimumDegree: 2)
        
        let element = BTreeElement(key: TestKey(id: 0), value: TestValue(value: "A"))
        let element2 = BTreeElement(key: TestKey(id: 1), value: TestValue(value: "B"))
        let element3 = BTreeElement(key: TestKey(id: 2), value: TestValue(value: "C"))
        let element4 = BTreeElement(key: TestKey(id: 3), value: TestValue(value: "D"))
        let element5 = BTreeElement(key: TestKey(id: 4), value: TestValue(value: "E"))
        
        try! tree.insert(element)
        try! tree.insert(element2)
        try! tree.insert(element3)
        try! tree.insert(element4)
        try! tree.insert(element5)
        
        XCTAssertEqual(try! tree.find(element4.key)?.value , element4.value.value)
        
        try? FileManager.default.removeItem(at: tempDirectory)
        
    }
    
    func testBTreeHarderMultiInsert() {
        var tempDirectory = FileManager.default.temporaryDirectory
        tempDirectory.appendPathComponent("testBTreeHarderMultiInsert.db")
        
        let tree = try! BTree<TestKey, TestValue>(storagePath: tempDirectory, minimumDegree: 2)
        
        let element = BTreeElement(key: TestKey(id: 0), value: TestValue(value: "A"))
        let element2 = BTreeElement(key: TestKey(id: 10), value: TestValue(value: "B"))
        let element3 = BTreeElement(key: TestKey(id: 20), value: TestValue(value: "C"))
        let element4 = BTreeElement(key: TestKey(id: 30), value: TestValue(value: "D"))
        let element5 = BTreeElement(key: TestKey(id: 40), value: TestValue(value: "E"))
        let element6 = BTreeElement(key: TestKey(id: 25), value: TestValue(value: "F"))
        let element7 = BTreeElement(key: TestKey(id: 22), value: TestValue(value: "G"))
        let element8 = BTreeElement(key: TestKey(id: 27), value: TestValue(value: "H"))
        let element9 = BTreeElement(key: TestKey(id: 21), value: TestValue(value: "I"))
        let element10 = BTreeElement(key: TestKey(id: 29), value: TestValue(value: "J"))
        
        try! tree.insert(element)
        try! tree.insert(element2)
        try! tree.insert(element3)
        try! tree.insert(element4)
        try! tree.insert(element5)
        try! tree.insert(element6)
        try! tree.insert(element7)
        try! tree.insert(element8)
        try! tree.insert(element9)
        try! tree.insert(element10)
        
        XCTAssertEqual(try! tree.find(element10.key)?.value , element10.value.value)
        
        try? FileManager.default.removeItem(at: tempDirectory)
        
    }
    
    // MARK: Storage Tests
    func testStorageInit() {
        var tempDirectory = FileManager.default.temporaryDirectory
        tempDirectory.appendPathComponent("testStorageInit.db")
        
        let storage = try! Storage<TestKey, TestValue>(path: tempDirectory)
        
        XCTAssertEqual(tempDirectory, storage.path)
        
        try? FileManager.default.removeItem(at: tempDirectory)
        
    }
    
    func testStorageSaveRoot() {
        var tempDirectory = FileManager.default.temporaryDirectory
        tempDirectory.appendPathComponent("testStorageSaveRoot.db")
        
        let storage = try! Storage<TestKey, TestValue>(path: tempDirectory)
        
        let rootNode = BTreeNode<TestKey, TestValue>(minimumDegree: 2, isLeaf: true)
        rootNode.isLoaded = true
        
        XCTAssertNoThrow(try storage.saveRoot(rootNode))
        
        try? FileManager.default.removeItem(at: tempDirectory)
        
    }
    
    func testStorageReadRoot() {
        var tempDirectory = FileManager.default.temporaryDirectory
        tempDirectory.appendPathComponent("testStorageReadRoot.db")
        
        let storage = try! Storage<TestKey, TestValue>(path: tempDirectory)
        
        let rootNode = BTreeNode<TestKey, TestValue>(minimumDegree: 2, isLeaf: true)
        rootNode.isLoaded = true
        
        XCTAssertNoThrow(try storage.saveRoot(rootNode))
        
        XCTAssertNoThrow(try storage.readRootNode())
        
        try? FileManager.default.removeItem(at: tempDirectory)
        
    }
    
    func testStorageFindNode() {
        var tempDirectory = FileManager.default.temporaryDirectory
        tempDirectory.appendPathComponent("testStorageFindNode.db")
        
        let storage = try! Storage<TestKey, TestValue>(path: tempDirectory)
        
        let rootNode = BTreeNode<TestKey, TestValue>(minimumDegree: 2, isLeaf: true)
        rootNode.isLoaded = true
        
        let offset = try! storage.saveRoot(rootNode)
        rootNode.offset = offset
        
        let root = try! storage.findNode(withOffset: offset)
        
        XCTAssertEqual(root.offset, rootNode.offset)
        
        try? FileManager.default.removeItem(at: tempDirectory)
        
    }
    
    func testStorageAppendRecord() {
        var storagePath = FileManager.default.temporaryDirectory
        storagePath.appendPathComponent("testStorageAppendRecord.db")
        
        let storage = try! Storage<TestKey, TestValue>(path: storagePath)
        
        let rootNode = BTreeNode<TestKey, TestValue>(minimumDegree: 2, isLeaf: true)
        rootNode.isLoaded = true
        
        let _ = try! storage.saveRoot(rootNode)
        
        let nodeToAppend = BTreeNode<TestKey, TestValue>(minimumDegree: 2, isLeaf: true)
        nodeToAppend.isLoaded = true
        
        XCTAssertNoThrow(try storage.append(nodeToAppend)) 
        
        try? FileManager.default.removeItem(at: storagePath)
        
    }
    
    func testStorageFindRecord() {
        var storagePath = FileManager.default.temporaryDirectory
        storagePath.appendPathComponent("testStorageFindRecord.db")
        
        let storage = try! Storage<TestKey, TestValue>(path: storagePath)
        
        let rootNode = BTreeNode<TestKey, TestValue>(minimumDegree: 2, isLeaf: true)
        rootNode.isLoaded = true
        
        let offset = try! storage.saveRoot(rootNode)
        
        XCTAssertEqual(try storage.findNode(withOffset: offset).offset, 20)
        
        try? FileManager.default.removeItem(at: storagePath)
        
    }
    
}
