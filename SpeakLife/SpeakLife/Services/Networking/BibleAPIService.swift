//
//  BibleAPIService.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import Foundation

protocol BibleAPIServiceProtocol {
    func fetchBooks() async throws -> [BibleBook]
    func fetchBook(abbrev: String) async throws -> BibleBook
    func fetchChapter(version: String, abbrev: String, chapter: Int) async throws -> BibleChapter
    func fetchVersions() async throws -> [BibleVersion]
    func searchVerses(version: String, query: String) async throws -> BibleSearchResponse
    func fetchRandomVerse(version: String) async throws -> RandomVerse
    func createUser(email: String, name: String, password: String, notifications: Bool) async throws -> BibleUserToken
    func loginUser(email: String, password: String) async throws -> BibleUserToken
}

struct BibleUserToken: Codable {
    let token: String
}

struct BibleUserRegistration: Codable {
    let name: String
    let email: String
    let password: String
    let notifications: Bool
}

struct BibleUserLogin: Codable {
    let email: String
    let password: String
}

enum BibleAPIError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case unauthorized
    case rateLimited
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized access"
        case .rateLimited:
            return "Rate limit exceeded. Please try again later."
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

final class BibleAPIService: BibleAPIServiceProtocol {
    static let shared = BibleAPIService()
    
    private let baseURL = "https://www.abibliadigital.com.br/api"
    private let session: URLSession
    private var authToken: String?
    private let defaultVersion = "kjv" // Default to KJV (King James Version)
    
    init(session: URLSession = .shared) {
        self.session = session
        loadAuthToken()
    }
    
    // MARK: - Books
    func fetchBooks() async throws -> [BibleBook] {
        let url = "\(baseURL)/books"
        return try await performRequest(url: url)
    }
    
    func fetchBook(abbrev: String) async throws -> BibleBook {
        let url = "\(baseURL)/books/\(abbrev)"
        return try await performRequest(url: url)
    }
    
    // MARK: - Chapters & Verses
    func fetchChapter(version: String = "kjv", abbrev: String, chapter: Int) async throws -> BibleChapter {
        let url = "\(baseURL)/verses/\(version)/\(abbrev)/\(chapter)"
        return try await performRequest(url: url)
    }
    
    // MARK: - Versions
    func fetchVersions() async throws -> [BibleVersion] {
        print("RWRW 📖 Fetching all Bible versions from API")
        let url = "\(baseURL)/versions"
        let versions: [BibleVersion] = try await performRequest(url: url)
        print("RWRW ✅ Successfully fetched \(versions.count) Bible versions")
        print("RWRW 📚 Available versions response:")
        for (index, version) in versions.enumerated() {
            print("RWRW   \(index + 1). Version Code: '\(version.version)' | Total Verses: \(version.verses)")
        }
        print("RWRW 📚 Full versions list: \(versions.map { $0.version }.joined(separator: ", "))")
        return versions
    }
    
    // MARK: - Search
    func searchVerses(version: String = "kjv", query: String) async throws -> BibleSearchResponse {
        let url = "\(baseURL)/verses/search"
        let body = BibleSearchRequest(version: version, search: query)
        return try await performRequest(url: url, method: "POST", body: body)
    }
    
    // MARK: - Random Verse
    func fetchRandomVerse(version: String = "kjv") async throws -> RandomVerse {
        let url = "\(baseURL)/verses/\(version)/random"
        return try await performRequest(url: url)
    }
    
    // MARK: - Authentication
    func createUser(email: String, name: String, password: String, notifications: Bool = true) async throws -> BibleUserToken {
        let url = "\(baseURL)/users"
        let body = BibleUserRegistration(name: name, email: email, password: password, notifications: notifications)
        let token: BibleUserToken = try await performRequest(url: url, method: "POST", body: body)
        saveAuthToken(token.token)
        return token
    }
    
    func loginUser(email: String, password: String) async throws -> BibleUserToken {
        let url = "\(baseURL)/users/token"
        let body = BibleUserLogin(email: email, password: password)
        let token: BibleUserToken = try await performRequest(url: url, method: "PUT", body: body)
        saveAuthToken(token.token)
        return token
    }
    
    // MARK: - Private Methods
    private func performRequest<T: Decodable, B: Encodable>(
        url urlString: String,
        method: String = "GET",
        body: B? = nil as String?
    ) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw BibleAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if provided
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        do {
            print("RWRW 🔍 Making request to: \(urlString)")
            print("RWRW 🔍 Method: \(method)")
            print("RWRW 🔍 Auth token present: \(authToken != nil)")
            
            let (data, response) = try await session.data(for: request)
            
            print("RWRW 🔍 Received response data size: \(data.count) bytes")
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("RWRW 🔍 HTTP Status Code: \(httpResponse.statusCode)")
                print("RWRW 🔍 Response Headers: \(httpResponse.allHeaderFields)")
                
                // Print response body for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("RWRW 🔍 Response Body: \(responseString)")
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    print("RWRW ✅ Success status code")
                    break // Success
                case 401:
                    print("RWRW ❌ Unauthorized error")
                    throw BibleAPIError.unauthorized
                case 429:
                    print("RWRW ❌ Rate limited error")
                    throw BibleAPIError.rateLimited
                case 400...499:
                    print("RWRW ❌ Client error: \(httpResponse.statusCode)")
                    throw BibleAPIError.serverError(httpResponse.statusCode)
                case 500...599:
                    print("RWRW ❌ Server error: \(httpResponse.statusCode)")
                    throw BibleAPIError.serverError(httpResponse.statusCode)
                default:
                    print("RWRW ❌ Unknown error: \(httpResponse.statusCode)")
                    throw BibleAPIError.serverError(httpResponse.statusCode)
                }
            }
            
            // Decode response
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(T.self, from: data)
                print("RWRW ✅ Successfully decoded response")
                return result
            } catch {
                print("RWRW ❌ Decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("RWRW 🔍 Raw response for decoding error: \(responseString)")
                }
                throw BibleAPIError.decodingError(error)
            }
        } catch let error as BibleAPIError {
            print("RWRW ❌ Bible API Error: \(error)")
            throw error
        } catch {
            print("RWRW ❌ Network Error: \(error)")
            print("RWRW 🔍 Network Error Details: \(error.localizedDescription)")
            throw BibleAPIError.networkError(error)
        }
    }
    
    // MARK: - Token Management
    private func saveAuthToken(_ token: String) {
        authToken = token
        let success = KeychainHelper.shared.save(token, forKey: "BibleAPIAuthToken")
        if success {
            print("✅ Auth token saved securely to Keychain")
        } else {
            print("❌ Failed to save auth token to Keychain")
        }
    }
    
    private func loadAuthToken() {
        authToken = KeychainHelper.shared.loadString(forKey: "BibleAPIAuthToken")
        if authToken != nil {
            print("✅ Auth token loaded from Keychain")
        } else {
            print("ℹ️ No auth token found in Keychain")
        }
    }
    
    func clearAuthToken() {
        authToken = nil
        let success = KeychainHelper.shared.delete(forKey: "BibleAPIAuthToken")
        if success {
            print("✅ Auth token cleared from Keychain")
        } else {
            print("❌ Failed to clear auth token from Keychain")
        }
    }
    
    var isAuthenticated: Bool {
        authToken != nil
    }
}