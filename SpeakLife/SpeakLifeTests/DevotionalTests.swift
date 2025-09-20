//
//  DevotionalTests.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/19/25.
//


import XCTest
@testable import SpeakLife // replace with your module name

final class DevotionalTests: XCTestCase {

    func testWelcomeDevotionalFormat() throws {
        guard let url = Bundle.main.url(forResource: "devotionals", withExtension: "json") else {
            XCTFail("Missing devotional.json file in test bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            do {
                _ = try JSONSerialization.jsonObject(with: data, options: [])
            } catch {
                XCTFail("Invalid JSON format: \(error) RWRW")
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
            
           
            
            let welcome = try decoder.decode(WelcomeDevotional.self, from: data)
            
            XCTAssertGreaterThan(welcome.devotionals.count, 0, "No devotionals found")
            
            for (index, devotional) in welcome.devotionals.enumerated() {
                let context = "Devotional #\(index + 1) – Title: \"\(devotional.title)\""
                
                if devotional.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    XCTFail("Empty title in \(context)")
                }
                
                if devotional.devotionalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    XCTFail("Empty devotionalText in \(context)")
                }
                
                if devotional.books.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    XCTFail("Empty books field in \(context)")
                }
                
                if !(devotional.books.contains(":") || devotional.books.contains("–")) {
                    XCTFail("Books field may be improperly formatted in \(context): \"\(devotional.books)\"")
                }
            }
            
        } catch let DecodingError.dataCorrupted(context) {
            XCTFail("Data corrupted: \(context.debugDescription)")
        } catch let DecodingError.keyNotFound(key, context) {
            XCTFail("Missing key '\(key.stringValue)' in \(context.debugDescription)")
        } catch let DecodingError.typeMismatch(type, context) {
            XCTFail("Type mismatch for \(type): \(context.debugDescription)")
        } catch let DecodingError.valueNotFound(value, context) {
            XCTFail("Missing value for \(value): \(context.debugDescription)")
        } catch {
            XCTFail("Unexpected JSON decoding error: \(error.localizedDescription)")
        }
    }

    func testDeclarationsFormat() throws {
        guard let url = Bundle.main.url(forResource: "declarationsv7", withExtension: "json") else {
            XCTFail("Missing devotional.json file in test bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            do {
                _ = try JSONSerialization.jsonObject(with: data, options: [])
            } catch {
                XCTFail("Invalid JSON format: \(error) RWRW")
            }
            
            let decoder = JSONDecoder()
           // decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
            
           
            
            let welcome = try decoder.decode(Welcome.self, from: data)
            
            XCTAssertGreaterThan(welcome.declarations.count, 0, "No devotionals found")
            
            
        } catch let DecodingError.dataCorrupted(context) {
            XCTFail("Data corrupted: \(context.debugDescription)")
        } catch let DecodingError.keyNotFound(key, context) {
            XCTFail("Missing key '\(key.stringValue)' in \(context.debugDescription)")
        } catch let DecodingError.typeMismatch(type, context) {
            XCTFail("Type mismatch for \(type): \(context.debugDescription)")
        } catch let DecodingError.valueNotFound(value, context) {
            XCTFail("Missing value for \(value): \(context.debugDescription)")
        } catch {
            XCTFail("Unexpected JSON decoding error: \(error.localizedDescription)")
        }
    }
        // MM-dd formatter to match expected JSON date format
        static var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }
}
