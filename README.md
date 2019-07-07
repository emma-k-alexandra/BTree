# BTree

BTree is a Swift implementation of an on-disk B-Tree, which can store Codable records.

## Contents
- [Requirements](#requirements)
- [Installation](#installation)
- [Disclaimer & Warnings](#disclaimer--warnings)
- [Design](#design)
- [Usage](#usage)
- [Getting Started](#getting-started)
- [On `minimumDegree`](#on-minimumdegree)
- [Using `BTree`](#using-btree)
- [Other Classes](#other-classes)
- [Dependencies](#dependencies)
- [Contributing](#contributing)
- [Contact](#contact)
- [License](#license)

## Requirements
- Swift 5.1+

## Installation

### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/emma-foster/BTree.git", from: "1.0.0")
]
```

## Disclaimer & Warnings
This is not a production-ready package. The current implementation of this B-Tree does not replicate the performance characteristics of a B-Tree as expected.

## Design
This B-Tree implementation is designed to use exclusively Swift, and relies heavily on [`Codable`](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types). I believe that `Codable` provides a friendly interface for storing and retrieving information from disk & will continue relying on `Codable` in the future.

This package is essentially split into two parts: `BTree` and `Storage`. `BTree` implements usual B-Tree operations. `Storage` implements actual storing and retrieving information from disk. In the future, I would like these two parts to be swappable and interchangeable, but I believe currently they are fairly intertwinged. This is definitely future work to be done on this project.

### Why use this B-Tree as opposed to [BTree](https://github.com/attaswift/BTree)?
This implementation of B-Tree uses this disk rather than storing the tree in-memory. In-memory data structures provide quick access to small datasets. On-disk implementations like this allow for storing much larger sets of data, while still maintaining relatively quick lookups (though, much slower than in-memory). If your dataset is small, use [BTree](https://github.com/attaswift/BTree). However, if your dataset is large, consider this implementation.

## Usage 

### Getting started
```swift
import BTree

struct TestKey: Comparable & Codable {
    static func < (lhs: TestKey, rhs: TestKey) -> Bool {
        return lhs.id < rhs.id

    }

    let id: Int

}

struct TestValue: Codable {
    let example: String

}

let tree = BTree<TestKey, TestValue>(storagePath: someFilePath)
let element = BTreeElement<TestKey, TestValue>(key: TestKey(id: 0), value: TestValue(example: "hello"))
try! tree.insert(element)

let element = try! tree.find(element.key)

print(element)
```

### On `minimumDegree`
`minimumDegree` is an argument for `BTree` which determines the number of elements that can be stored in each node. `minimumDegree` is exactly **minimum degree** (Introduction to Algorithms, 3rd Edition, Cormen et al, Section 18.1, page 489). `minimumDegree` states that the minimum number of elements of a non-root node is `minimumDegree - 1`, the maximum number of elements of any node is `2 * minimumDegree - 1`. Additionally, `minimumDegree` provides limits on children of a node. Minimum number of children in an internal node: `minimumDegree`, maximum number of children `2 * minimumDegree`. This implementation follows these definitions.

---

### Using `BTree`
`BTree` provides operations typical of a search tree.

#### `find`
 Find the provided key within the B-Tree. Exactly the same as searching on the root node.
 
 ```swift
 let value = try! tree.find(TestKey(id: 0))
 ```
 
 #### `insert`
 Inserts an element into the B-Tree.
 
 ```swift
 let element = BTreeElement<TestKey, TestValue>(key: TestKey(id: 0), value: TestValue(example: "hello"))
 try! tree.insert(element)
 ```
 
 --- 
 
 ### Other Classes
 These classes are only required to understand the implementation of this B-Tree.
 
 #### Using `BTreeNode`
 ##### `find`
 Finds the given key in this node.
 
 ```swift
 let value = try! node.find(TestKey(id: 0))
 ```
 
 ##### `insertNonFull`
 Inserts an element into this node, if the node is not full.

```swift
try! node.insertNonFull(element)
```

##### `split`
Splits a node a the given child.

```swift
try! node.split(at: 0)
```

##### `save`
Saves a node using the current storage engine

```swift
try! node.save()
```

##### `load`
Loads a node from the current storage engine

```swift
try! node.load()
```

---

#### Using `Storage`
The storage engine for the B-Tree. Interacts with the disk.

##### `isEmpty`
If the current file used for storage is empty.

```swift
storage.isEmpty()
```

##### `close`
Closes the current file of operation.

```swift
storage.close()
```

##### `saveRoot`
Saves a new root to disk.

```swift
let node = BTreeNode<TestKey, TestValue>(minimumDegree: 2, isLeaf: true)
node.id = UUID()
node.isLoaded = true

try! storage.saveRoot(node)
```

##### `readRootNode`
Reads the current root node from disk.

```swift
let root = try! storage.readRootNode()
```

##### `findNode`
Finds a node on disk.

```swift
let node = try! storage.findNode(withId: UUID().uuidString)
```

##### `upsert`
Inserts or updates the given node on disk.

```swift
try! storage.upsert(node)
```

##### `transfer`
Tranfers the given range from one file to another. Used when updating records.

```swift
storage.transfer(from: file1, to: file2, in: 0..<5)
```

##### `append`
Appends a node to storage on disk.

```swift
try! storage.append(node)
```

##### `findRecord`
Finds the range of a record on disk.

```swift
storage.findRecord(UUID().uuidString)
```

## Dependencies
None

## Contributing
This package still requires a lot of work in order to achieve performance characteristics of a B-Tree. This will be the main focus of my contributions to this project. But, there are many other areas of improvement (decoupling `BTree` and `Storage`, deletion of elements) and all outside contributions are welcome. Feel free to submit PRs or Issues on this package's [GitHub](https://github.com/emma-foster/BTree).

## Contact
Feel free to email questions and comments to [emma@emma.sh](mailto:emma@emma.sh). 

## License

WMATA.swift is released under the MIT license. [See LICENSE](https://github.com/emma-foster/BTree/blob/master/LICENSE) for details.

