//
//  TestimonyViewModel.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 3/17/25.
//
import SwiftUI
import FirebaseFirestore
import Network

// MARK: - Model
struct TestimonialPost: Identifiable, Codable {
    @DocumentID var id: String?
    let text: String
    let user: String
    let timestamp: Timestamp
    let deviceId: String
    var reports: Int = 0 // Track the number of reports
    var isHidden: Bool = false
}

// MARK: - ViewModel
class TestimonyViewModel: ObservableObject {
    @Published var testimonies: [TestimonialPost] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSubmitting = false
    @Published var submissionMessage: String?
    @Published var isShowingForm = false
    
    private let db = Firestore.firestore()
    private let collection = "testimonies"
    private let batchSize = 10
    private let reportThreshold = 5 // Number of reports before hiding
    private let dailyPostLimit = 3
    private let cacheKey = "cachedTestimonies"
    private let lastFetchKey = "lastFetchTimestamp"
    private let fetchCooldown: TimeInterval = 300
    private let dailyFetchKey = "dailyFetchTimestamp"
    private let dailyCooldown: TimeInterval = 86400
    private var lastDocument: DocumentSnapshot?
    private var listener: ListenerRegistration?
    private let deviceId: String
    private let networkMonitor = NWPathMonitor()
    
    init() {
        self.deviceId = TestimonyViewModel.getDeviceId()
        loadCachedTestimonies()
        preloadTestimonies()
        monitorNetwork()
        fetchTestimoniesIfNeeded()
    }
    
    private func loadCachedTestimonies() {
            if let data = UserDefaults.standard.data(forKey: cacheKey),
               let decoded = try? JSONDecoder().decode([TestimonialPost].self, from: data) {
                self.testimonies = decoded
            }
        }
        
        private func cacheTestimonies() {
            if let encoded = try? JSONEncoder().encode(testimonies) {
                UserDefaults.standard.set(encoded, forKey: cacheKey)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
            }
        }
    
    private func preloadTestimonies() {
            let fakeDeviceId = "test-device-123"
            let sampleTestimonies = [
                TestimonialPost(text: "I was lost, but Jesus found me and turned my life around.", user: "Kristin", timestamp: Timestamp(), deviceId: fakeDeviceId),
                TestimonialPost(text: "I suffered from depression, but speaking life over myself and trusting God brought me healing.", user: "Jelena", timestamp: Timestamp(), deviceId: fakeDeviceId),
                TestimonialPost(text: "I used to be an atheist, but Jesus showed me His love and grace, changing my entire perspective.", user: "Niall", timestamp: Timestamp(), deviceId: fakeDeviceId),
                TestimonialPost(text: "Even in captivity, I felt God's presence and protection guiding me to freedom.", user: "Bethany", timestamp: Timestamp(), deviceId: fakeDeviceId),
                TestimonialPost(text: "I encountered Jesus in the most unexpected way, and now my faith is unshakable.", user: "Anonymous", timestamp: Timestamp(), deviceId: fakeDeviceId),
                TestimonialPost(text: "When I started declaring God's promises, doors opened that I never imagined possible.", user: "Chris", timestamp: Timestamp(), deviceId: fakeDeviceId),
                TestimonialPost(text: "After years of struggling, Jesus brought breakthrough into my finances and relationships.", user: "David", timestamp: Timestamp(), deviceId: fakeDeviceId),
                TestimonialPost(text: "I spoke healing over my body, and I witnessed a miracle unfold before my eyes.", user: "Grace", timestamp: Timestamp(), deviceId: fakeDeviceId),
                TestimonialPost(text: "The power of Jesus' name turned my despair into joy overnight.", user: "Samuel", timestamp: Timestamp(), deviceId: fakeDeviceId),
                TestimonialPost(text: "I had no hope, but Jesus restored my family and gave me a future.", user: "Olivia", timestamp: Timestamp(), deviceId: fakeDeviceId)
            ]
            
            for testimony in sampleTestimonies {
                do {
                    _ = try db.collection(collection).addDocument(from: testimony)
                } catch {
                    print("Error preloading testimonies: \(error.localizedDescription)")
                }
            }
        }
        
    private func fetchTestimoniesIfNeeded() {
        let lastFetch = UserDefaults.standard.double(forKey: lastFetchKey)
        let lastDailyFetch = UserDefaults.standard.double(forKey: dailyFetchKey)
        let now = Date().timeIntervalSince1970
        
        if now - lastDailyFetch > dailyCooldown {
            // Fetch once per day
            fetchTestimonies(reset: true)
            UserDefaults.standard.set(now, forKey: dailyFetchKey)
        } else if now - lastFetch > fetchCooldown {
            // Fetch only if user pulls down after cooldown period
            fetchTestimonies(reset: true)
        }
    }

    
    static func getDeviceId() -> String {
        let key = "uniqueDeviceId"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: key)
            return newId
        }
    }
    
    private func monitorNetwork() {
        networkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .unsatisfied {
                    self.errorMessage = "No internet connection. Some features may not work."
                }
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    func addTestimony(user: String, text: String) {
        if networkMonitor.currentPath.status == .unsatisfied {
            errorMessage = "You are offline. Please connect to the internet to submit a testimony."
            return
        }
        guard !text.isEmpty else {
            self.errorMessage = "Testimony cannot be empty."
            return
        }
        
        guard text.count <= 500 else {
            self.errorMessage = "Testimony exceeds 500 character limit."
            return
        }
        
        getTodaysPostCount(for: user) { [weak self] count in
            guard let self = self else { return }
            if count >= self.dailyPostLimit {
                DispatchQueue.main.async {
                    self.errorMessage = "You have reached your daily limit of \(self.dailyPostLimit) testimonies."
                }
                return
            }
        }
        
        
        isSubmitting = true
        let newTestimony = TestimonialPost(text: text, user: user, timestamp: Timestamp(), deviceId: self.deviceId)
        
        do {
            _ = try db.collection(collection).addDocument(from: newTestimony) { error in
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    if let error = error {
                        if (error as NSError).domain == NSURLErrorDomain {
                            self.errorMessage = "Network error while posting. Please try again later."
                        } else if let error = error as NSError?, error.domain == FirestoreErrorDomain {
                            if error.code == FirestoreErrorCode.permissionDenied.rawValue {
                            self.errorMessage = "You don’t have permission to post testimonies."
                            return
                        }
                        } else {
                        self.errorMessage = "Error submitting testimony: \(error.localizedDescription)"
                    }
                } else {
                    self.submissionMessage = "Testimony added successfully!"
                    self.fetchTestimonies(reset: true)
                }
            }
        }
        } catch {
            DispatchQueue.main.async {
                self.isSubmitting = false // Re-enable button on failure
                self.errorMessage = "Unexpected error occurred."
            }
        }
}

    func getTodaysPostCount(for user: String, completion: @escaping (Int) -> Void) {
        let localStartOfDay = Calendar.current.startOfDay(for: Date()) // Local timezone
        let utcStartOfDay = Calendar(identifier: .gregorian).date(byAdding: .second, value: -TimeZone.current.secondsFromGMT(), to: localStartOfDay) ?? localStartOfDay
           
        let query = db.collection(collection)
            .whereField("deviceId", isEqualTo: deviceId)
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: utcStartOfDay))
        
        query.getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching user post count: \(error.localizedDescription)")
                completion(0)
                return
            }
            completion(snapshot?.documents.count ?? 0)
        }
    }
    
    func fetchTestimonies(reset: Bool = false, retryCount: Int = 3) {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        
        var query: Query = db.collection(collection)
            .order(by: "timestamp", descending: true)
            .whereField("isHidden", isEqualTo: false)
            .limit(to: batchSize)
        
        if let lastDoc = lastDocument, !reset {
            query = query.start(afterDocument: lastDoc)
        }
        
        query.getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error as NSError?, error.code == FirestoreErrorCode.resourceExhausted.rawValue {
                    let retryDelay = pow(2.0, Double(3 - retryCount)) // Exponential backoff
                    DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
                        self.fetchTestimonies(reset: reset, retryCount: retryCount - 1)
                        return
                    }
                }
                
                if let error = error as NSError?, error.domain == NSURLErrorDomain {
                    if error.code == FirestoreErrorCode.permissionDenied.rawValue {
                        self.errorMessage = "You don’t have permission to view testimonies."
                        return
                    }
                    if retryCount > 0 {
                        print("Network error. Retrying fetch in 2 seconds...")
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                            self.fetchTestimonies(reset: reset, retryCount: retryCount - 1)
                        }
                    } else {
                        self.errorMessage = "Network error. Please check your internet connection and try again."
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.errorMessage = "No testimonies found."
                    return
                }
                
                let newTestimonies = documents.compactMap { try? $0.data(as: TestimonialPost.self) }
                if reset {
                    self.testimonies = newTestimonies
                } else {
                    self.testimonies.append(contentsOf: newTestimonies)
                }
                self.cacheTestimonies()
                
                self.lastDocument = documents.last
            }
        }
    }
    
    func reportTestimony(testimony: TestimonialPost) {
        guard let id = testimony.id else { return }
        let testimonyRef = db.collection(collection).document(id)
        
        testimonyRef.updateData(["reports": FieldValue.increment(Int64(1))]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error reporting testimony: \(error.localizedDescription)"
                } else {
                    self.submissionMessage = "Testimony reported successfully!"
                    self.checkAndHideTestimony(id: id, currentReports: testimony.reports + 1)
                }
            }
        }
    }
    
    private func checkAndHideTestimony(id: String, currentReports: Int) {
        if currentReports >= reportThreshold {
            let testimonyRef = db.collection(collection).document(id)
            testimonyRef.updateData(["isHidden": true]) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Error hiding testimony: \(error.localizedDescription)"
                    } else {
                        self.fetchTestimonies(reset: true) // Refresh feed
                    }
                }
            }
        }
    }
    
    func refresh() {
        lastDocument = nil
        fetchTestimonies(reset: true)
    }
    
    deinit {
        listener?.remove()
    }
}
