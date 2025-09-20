//
//  ProfileBarView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/2/22.
//

import SwiftUI

final class ProfileBarButtonViewModel: ObservableObject {
    @Published var isPresentingProfileView = false
}

struct ProfileBarButton: View {
    
    // MARK: - Properties
    
   
    @StateObject var viewModel: ProfileBarButtonViewModel
    
    
    var body: some View {
        
        HStack {
            Spacer()
            CapsuleImageButton(title: "person.crop.circle") {
                profileButtonTapped()
                Selection.shared.selectionFeedback()
            }.sheet(isPresented: $viewModel.isPresentingProfileView, onDismiss: {
                self.viewModel.isPresentingProfileView = false
            }, content: {
                ProfileView()
            })
            .foregroundColor(.white)
            
            
        }.padding()
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                self.viewModel.isPresentingProfileView = false
                    }
    }
    
    // MARK: - Intent(s)
    
    private func profileButtonTapped() {
        self.viewModel.isPresentingProfileView = true
    }
}

struct ProfileBarView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileBarButton(viewModel: ProfileBarButtonViewModel())
    }
}

