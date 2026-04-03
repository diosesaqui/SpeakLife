//
//  FaithJourneyViewModel.swift
//  SpeakLife
//
//  Manages the active 21-Day Faith Journey:
//  starting, completing daily check-ins, milestone alerts, Firestore persistence.
//

import Foundation
import FirebaseFirestore
import UserNotifications
import SwiftUI

@MainActor
final class FaithJourneyViewModel: ObservableObject {

    // MARK: - Published State

    @Published var activeJourney: FaithJourney?
    @Published var completedJourneys: [FaithJourney] = []
    @Published var isLoading = false
    @Published var showMilestoneAlert = false
    @Published var currentMilestone: JourneyMilestone?
    @Published var showCategoryPicker = false

    // MARK: - Private

    private let db = Firestore.firestore()
    private var userId: String?

    // MARK: - Configure

    func configure(userId: String) {
        self.userId = userId
        Task { await loadJourney() }
    }

    // MARK: - Start Journey

    func startJourney(categoryId: String, categoryName: String) async {
        guard let uid = userId else { return }
        isLoading = true
        defer { isLoading = false }

        // Archive any existing active journey first
        if var existing = activeJourney {
            existing.isActive = false
            await saveJourney(existing)
        }

        let journey = FaithJourney(userId: uid, categoryId: categoryId, categoryName: categoryName)
        activeJourney = journey
        await saveJourney(journey)
    }

    // MARK: - Complete Today's Day

    /// Call this when the user speaks their declarations on a journey day.
    func completeTodaysDay() async {
        guard var journey = activeJourney else { return }
        let today = journey.currentDay
        guard !journey.completedDaySet.contains(today) else { return }

        journey.completedDays.append(today)
        activeJourney = journey
        await saveJourney(journey)
        checkMilestones(journey: journey, completedDay: today)
    }

    // MARK: - Milestone Handling

    private func checkMilestones(journey: FaithJourney, completedDay: Int) {
        switch completedDay {
        case 7:  fire(.day7Badge)
        case 14: fire(.day14BonusAudio)
        case 21: fire(.day21Mastery); archiveCompletedJourney()
        default: break
        }
    }

    private func fire(_ milestone: JourneyMilestone) {
        currentMilestone = milestone
        showMilestoneAlert = true
        schedulePush(milestone)
    }

    private func archiveCompletedJourney() {
        guard var journey = activeJourney else { return }
        journey.isActive = false
        completedJourneys.append(journey)
        activeJourney = nil
        Task { await saveJourney(journey) }
    }

    // MARK: - Push Notifications

    private func schedulePush(_ milestone: JourneyMilestone) {
        let content = UNMutableNotificationContent()
        content.title = milestone.title
        content.body  = milestone.message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "journey_milestone_\(milestone.day)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Firestore

    private func loadJourney() async {
        guard let uid = userId else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db
                .collection("users").document(uid)
                .collection("faithJourneys")
                .whereField("isActive", isEqualTo: true)
                .limit(to: 1)
                .getDocuments()

            if let doc = snapshot.documents.first {
                activeJourney = try doc.data(as: FaithJourney.self)
            }

            // Also load completed journeys for history
            let history = try await db
                .collection("users").document(uid)
                .collection("faithJourneys")
                .whereField("isActive", isEqualTo: false)
                .order(by: "startDate", descending: true)
                .limit(to: 10)
                .getDocuments()

            completedJourneys = history.documents.compactMap { try? $0.data(as: FaithJourney.self) }

        } catch {
            print("FaithJourneyViewModel ▶ load error: \(error.localizedDescription)")
        }
    }

    private func saveJourney(_ journey: FaithJourney) async {
        guard let uid = userId else { return }
        do {
            try db
                .collection("users").document(uid)
                .collection("faithJourneys")
                .document(journey.id)
                .setData(from: journey)
        } catch {
            print("FaithJourneyViewModel ▶ save error: \(error.localizedDescription)")
        }
    }
}
