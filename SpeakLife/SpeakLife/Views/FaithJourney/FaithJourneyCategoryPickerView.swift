//
//  FaithJourneyCategoryPickerView.swift
//  SpeakLife
//
//  Sheet that lets the user choose a category before starting a 21-Day Faith Journey.
//

import SwiftUI

struct FaithJourneyCategoryPickerView: View {

    @ObservedObject var viewModel: FaithJourneyViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(JourneyCategory.all) { category in
                Button {
                    Task {
                        await viewModel.startJourney(
                            categoryId:   category.id,
                            categoryName: category.displayName
                        )
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 16) {
                        Text(category.emoji)
                            .font(.title2)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("21-day commitment")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Choose Your Journey")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.6))
                }
            }
        }
    }
}

#if DEBUG
struct FaithJourneyCategoryPickerView_Previews: PreviewProvider {
    static var previews: some View {
        FaithJourneyCategoryPickerView(viewModel: FaithJourneyViewModel())
    }
}
#endif
