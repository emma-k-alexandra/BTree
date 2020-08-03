//
//  BTreeError.swift
//  
//
//  Created by Emma K Alexandra on 8/3/20.
//

import Foundation

/// All possible errors that can occur between the B-Tree and the storage engine
enum BTreeError: Error {
    case duplicateKey
    case unableToInsert
    case nodeIsNotLoaded
    case unableToLoadNode
    case unableToReadDatabase
    case unableToCreateStorage
    case unableToModifyTemporaryDatabase
    case unableToRenameTemporaryDatabase
    case invalidStorage
    case invalidRootRecord
    case invalidRecord
    case invalidRecordSize
    case storageMarkedReadOnly
}
