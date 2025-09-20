//
//  TestimonyView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 3/17/25.
//

import SwiftUI
import FirebaseFirestore

// MARK: - View
struct TestimonyRow: View {
    let testimony: TestimonialPost
    let reportAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(testimony.user)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 22, relativeTo: .headline))
                .foregroundColor(.blue)
            
            Text(testimony.text)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 18, relativeTo: .body))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            Text("Posted on \(formattedDate(testimony.timestamp))")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .caption))
                .foregroundColor(.gray)
            
//            Button(action: reportAction) {
//                HStack {
//                    Image(systemName: "flag.fill")
//                    Text("Report")
//                }
//                .font(.caption)
//                .foregroundColor(.red)
//            }
//            .buttonStyle(BorderlessButtonStyle())
        }
        .padding()
    }
    
    private func formattedDate(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Testimony Feed View
struct TestimonyFeedView: View {
    @StateObject private var viewModel = TestimonyViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                TestimonyListView(viewModel: viewModel)
                Button(action: {
                    viewModel.isShowingForm = true
                }) {
                    Text("Share Your Testimony")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
                .sheet(isPresented: $viewModel.isShowingForm) {
                    TestimonyFormView().environmentObject(viewModel)
                }
            }
            
            .navigationTitle("Testimonies")
            .alert(isPresented: Binding<Bool>(
                get: { viewModel.submissionMessage != nil || viewModel.errorMessage != nil },
                set: { _ in
                    viewModel.submissionMessage = nil
                    viewModel.errorMessage = nil
                }
            )) {
                Alert(title: Text(viewModel.errorMessage != nil ? "Error" : "Success"),
                      message: Text(viewModel.errorMessage ?? viewModel.submissionMessage ?? ""),
                      dismissButton: .default(Text("OK")))
            }
        }
    }
}

// MARK: - Testimony List View
struct TestimonyListView: View {
    @ObservedObject var viewModel: TestimonyViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.testimonies) { testimony in
                TestimonyRow(testimony: testimony) {
                    viewModel.reportTestimony(testimony: testimony)
                }
            }
        }
        .refreshable {
            viewModel.fetchTestimonies(reset: true)
        }
    }
}


// MARK: - Preview
struct TestimonyFeedView_Previews: PreviewProvider {
    static var previews: some View {
        TestimonyFeedView()
    }
}

struct TestimonyFormView: View {
    @State private var userName: String = ""
    @State private var testimonyText: String = ""
    @EnvironmentObject var viewModel: TestimonyViewModel
    @Environment(\.presentationMode) var presentationMode
    private let characterLimit = 500
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Your Name")) {
                    TextField("Enter your name", text: $userName)
                }
                
                Section(header: Text("Your Testimony")) {
                    TextEditor(text: $testimonyText)
                        .frame(minHeight: 100)
                        .onChange(of: testimonyText) { newValue in
                            if newValue.count > characterLimit {
                                testimonyText = String(newValue.prefix(characterLimit))
                            }
                        }
                    Text("\(testimonyText.count)/500 characters")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Section {
                    Button(action: submitTestimony) {
                        if viewModel.isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Submit Testimony")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .modifier(SubmitButtonModifier(isDisabled: viewModel.isSubmitting || userName.isEmpty || testimonyText.count > 10))
                    .disabled(viewModel.isSubmitting || userName.isEmpty || testimonyText.count > 10)
                }
            }
            .navigationTitle("Share Your Testimony")
        }
    }
    
    private func submitTestimony() {
        viewModel.addTestimony(user: userName, text: testimonyText)
    }
}


struct SubmitButtonModifier: ViewModifier {
    let isDisabled: Bool
    
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding()
            .background(isDisabled ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}
