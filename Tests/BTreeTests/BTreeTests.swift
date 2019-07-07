import XCTest
@testable import BTree

@available(OSX 10.12, *)
final class BTreeTests: XCTestCase {
    struct TestKey: Comparable & Codable {
        static func < (lhs: BTreeTests.TestKey, rhs: BTreeTests.TestKey) -> Bool {
            return lhs.id < rhs.id
        }
        
        let id: Int
    }
    
    struct TestValue: Codable {
        let value: String
    }
    
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
    
}
