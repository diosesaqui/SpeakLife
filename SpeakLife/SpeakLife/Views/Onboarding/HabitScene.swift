//
//  HabitScene.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 1/9/24.
//

import SwiftUI

struct HabitScene: View {
    
    let size: CGSize
    let callBack: (() -> Void)
    @StateObject var viewModel = ExperienceViewModel()
   
    
    var body: some  View {
        habitView(size: size)
    }
    
    private func habitView(size: CGSize) -> some View  {
        VStack {
            Spacer().frame(height: 90)
            
            VStack {

                VStack {
                    Text("How familiar are you with affirmations?" , comment: "Intro scene instructions")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .foregroundColor(Constants.DALightBlue)
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .lineLimit(nil)
                    
                    Spacer().frame(height: 24)
                    
                    ExperienceSelectionListView(viewModel:viewModel)
                }
                .frame(width: size.width * 0.9)
            }
            Spacer()
            Text(viewModel.selectedExperience?.subtitle ?? "")
                .lineLimit(2)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .body))
                .padding()
            
            Button(action: callBack) {
                HStack {
                    Text("Continue", comment: "Intro scene start label")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .fontWeight(.medium)
                        .frame(width: size.width * 0.91 ,height: 50)
                }.padding()
            }
            .disabled(viewModel.selectedExperience == nil)
            .frame(width: size.width * 0.87 ,height: 50)
            .background(viewModel.selectedExperience == nil ? Constants.DAMidBlue.opacity(0.5): Constants.DAMidBlue)
            
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)
            
            Spacer()
                .frame(width: 5, height: size.height * 0.07)
            
            
        }
        .frame(width: size.width, height: size.height)
        .background(
            Image("declarationBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
        )
        
    }
}


class ExperienceViewModel: ObservableObject {
    @Published var selectedExperience: Experience?
    
    func selectExperience(_ experience: Experience) {
        selectedExperience = experience
    }
}

enum Experience: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    
    var subtitle: String {
        switch self {
        case .beginner:
            return "No worries, we all start out that way"
        case .intermediate:
            return "Awesome, let's dive deeper into your SpeakLife journey"
        case .advanced:
            return "Wow, let's explore new territory together"
        }
    }
}

struct ExperienceSelectionListView: View {
    @ObservedObject var viewModel: ExperienceViewModel
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        VStack {
            
            ForEach(Experience.allCases, id: \.self) { experience in
                Button(action: {
                    impactMed.impactOccurred()
                    viewModel.selectExperience(experience)
                }) {
                    HStack {
                        Text(experience.rawValue)
                            .foregroundColor(.white)
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        Spacer()
                        if viewModel.selectedExperience == experience {
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .background(Constants.DAMidBlue.opacity(viewModel.selectedExperience == experience ? 0.8 : 0.3))
                .cornerRadius(10)
            }
            Spacer()
                .frame(height: 24)
            
            
        }
        .padding()
    }
}


