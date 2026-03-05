//
//  BibleVersionSelectorView.swift
//  SpeakLife
//
//  Created by SpeakLife Team on 1/28/26.
//

import SwiftUI

struct BibleVersionSelectorView: View {
    @ObservedObject var viewModel: BibleViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Gradients().speakLifeCYOCell
                    .ignoresSafeArea(.all)
                
                Group {
                    if viewModel.availableVersions.isEmpty {
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.2)
                            
                            Text("Loading Bible versions...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.availableVersions) { version in
                                    BibleVersionRow(
                                        version: version,
                                        isSelected: version.version == viewModel.selectedVersion
                                    ) {
                                        Task { 
                                            await viewModel.changeVersion(version.version)
                                            dismiss()
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                }
                            }
                            .padding(.top)
                        }
                    }
                }
            }
            .navigationTitle("Bible Version")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(.stack)
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            Task {
                if viewModel.availableVersions.isEmpty {
                    await viewModel.loadAvailableVersions()
                }
            }
        }
    }
}