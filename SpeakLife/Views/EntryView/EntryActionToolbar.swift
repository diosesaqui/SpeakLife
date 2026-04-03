//
//  EntryActionToolbar.swift
//  SpeakLife
//
//  Bottom action toolbar for save/cancel functionality in journal and affirmation entries
//

import SwiftUI

struct EntryActionToolbar: View {
    @ObservedObject var viewModel: EntryViewModel
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Progress info
            if !viewModel.text.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.progressInfo)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    if viewModel.shouldShowLengthWarning {
                        Text(viewModel.recommendedLengthMessage)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            // Buttons container with fixed width
            HStack(spacing: 12) {
                // Cancel button
                Button(action: onCancel) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                }
                .disabled(viewModel.isSaving)
                .frame(minWidth: 80)
                
                // Save button
                Button(action: onSave) {
                    HStack(spacing: 8) {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                        Text(viewModel.isSaving ? "Saving..." : "Save")
                            .font(.system(size: 16, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        viewModel.canSave ? 
                        Color.blue.opacity(0.8) : 
                        Color.white.opacity(0.2)
                    )
                    .cornerRadius(20)
                }
                .disabled(!viewModel.canSave || viewModel.isSaving)
                .frame(minWidth: 90)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.1),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
}

// MARK: - Preview
#if DEBUG
struct EntryActionToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            
            EntryActionToolbar(
                viewModel: EntryViewModel(contentType: .affirmation),
                onSave: {},
                onCancel: {}
            )
        }
        .background(Color.black)
        .previewDisplayName("Entry Action Toolbar")
    }
}
#endif