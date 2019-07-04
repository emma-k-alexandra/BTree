import XCTest

import BTreeTests

var tests = [XCTestCaseEntry]()
tests += BTreeTests.allTests()
XCTMain(tests)
