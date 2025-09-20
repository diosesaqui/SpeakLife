//
//  DailyChecklistFullScreenView.swift
//  SpeakLife
//
//  Standalone full-screen view for daily checklist
//

import SwiftUI

struct DailyChecklistFullScreenView: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background gradient
            Gradients().speakLifeCYOCell
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation bar with close button
                HStack {
                    Text("Daily Practice")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Main checklist content
                DailyChecklistView(viewModel: viewModel)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                Spacer()
            }
        }
    }
}

#if DEBUG
struct DailyChecklistFullScreenView_Previews: PreviewProvider {
    static var previews: some View {
        DailyChecklistFullScreenView(viewModel: EnhancedStreakViewModel())
    }
}
#endif