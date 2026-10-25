//
//  TrackerView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/11/23.
//

import SwiftUI
import SwiftUICharts

struct TrackerView: View {
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var timeTracker: TimeTrackerViewModel
    @State var shareSheetShowing = false
    @State private var image: UIImage?
    
    var body: some View {
        VStack {
            //            Text("Total time spent Speaking Life 🗣: \(timeTracker.totalTimeValue)")
            //                .font(.title)
            
            LineView(data: timeTracker.minutesPerDay, title: "Total time spent Speaking Life 🗣: \(timeTracker.totalTimeValue)", legend: "minutes per session", style: Styles.barChartStyleNeonBlueLight)
            Button("Share time spent") {
                //DispatchQueue.main.asyncAfter(deadline: .now()) {
                //image = snapshot()
                shareSheetShowing = true
//                if let windowScene =  UIApplication.shared.connectedScenes.first as? UIWindowScene {
//                    if let window = windowScene.windows.first {
//                        image = window.rootViewController?.view.toImage()
//
//                    }
//                }
                
 //           }
            }
        }
        .padding()
        .onAppear {
            appState.newTrackerAdded = false
            timeTracker.calculateElapsedTime()
        }
        .sheet(isPresented: $shareSheetShowing) {
                
                ShareSheet(activityItems: [shareText])
        }
    }

    /// Falls back to a line with no number before a full minute is counted,
    /// so the share never says "I've spent 0 minutes". Formatted from the raw
    /// total, not `totalTimeValue`, so it reads "1 minute", not "1 minutes".
    /// The tracked link is added only for messaging apps.
    private var shareText: ReferralShareText {
        let total = timeTracker.calculateTotalTime(minutesArray: timeTracker.minutesPerDay)
        let minutes = total.totalHours * 60 + total.totalMinutes
        let words: String
        if minutes >= 1, let time = Self.durationFormatter.string(from: TimeInterval(minutes * 60)) {
            words = "I've spent \(time) speaking God's Word over my life with SpeakLife. Join me."
        } else {
            words = "I'm speaking God's Word over my life every day with SpeakLife. Join me."
        }
        return ReferralShareText(words, link: ReferralLink.url(.tracker))
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        return formatter
    }()
}
