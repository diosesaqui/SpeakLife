//
//  APIClientTests.swift
//  SpeakLifeTests
//
//  Created by Riccardo Washington on 3/28/23.
//

import XCTest
//@testable import SpeakLife

//final class APIClientTests: XCTestCase {
//
//    func testLoadFromBackend() {
//        let apiClient = APIClient()
//        let expectation = XCTestExpectation(description: "Loading declarations from the backend")
//
//        apiClient.loadFromBackEnd { declarations, error in
//            XCTAssertNotNil(declarations, "Declarations should not be nil")
//            XCTAssertNil(error, "Error should be nil")
//            XCTAssertEqual(declarations.count, 10, "Expected 10 declarations")
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: 10.0)
//    }
//
//    func testLoadFromDisk() {
//        let apiClient = APIClient()
//        let expectation = XCTestExpectation(description: "Loading declarations from disk")
//
//        apiClient.loadFromDisk { declarations, error in
//            XCTAssertNotNil(declarations, "Declarations should not be nil")
//            XCTAssertNil(error, "Error should be nil")
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: 10.0)
//    }
//
//    func testSaveToDisk() {
//        let apiClient = APIClient()
//        let declarations = [Declaration(id: "1", text: "Declaration 1", category: .faith, isFavorite: false)]
//        let expectation = XCTestExpectation(description: "Saving declarations to disk")
//
//        apiClient.save(declarations: declarations) { success in
//            XCTAssertTrue(success, "Saving declarations to disk should succeed")
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: 10.0)
//    }
//
//    func testSyncDeclarations() {
//        let apiClient = APIClient()
//        let expectation = XCTestExpectation(description: "Syncing declarations")
//
//        apiClient.syncDeclarations { needsSync in
//            XCTAssertTrue(needsSync, "Declarations should need sync")
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: 10.0)
//    }
//
//    func testLoadSelectedCategoriesFromDisk() {
//        let apiClient = APIClient()
//        let expectation = XCTestExpectation(description: "Loading selected categories from disk")
//
//        apiClient.loadSelectedCategoriesFromDisk { categories, error in
//            XCTAssertNotNil(categories, "Categories should not be nil")
//            XCTAssertNil(error, "Error should be nil")
//            XCTAssertEqual(categories.count, 2, "Expected 2 categories")
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: 10.0)
//    }
//
//    func testSaveSelectedCategories() {
//        let apiClient = APIClient()
//        let categories: Set<DeclarationCategory> = [.faith, .gratitude]
//        let expectation = XCTestExpectation(description: "Saving selected categories to disk")
//
//        apiClient.save(selectedCategories: categories) { success in
//            XCTAssertTrue(success, "Saving selected categories to disk should succeed")
//            expectation.fulfill()
//        }
//
//        wait(for: [expectation], timeout: 10.0)
//    }
//}
