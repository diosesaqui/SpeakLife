//
//  FontPickerController.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/9/22.
//

import UIKit
import SwiftUI

import SwiftUI
import UIKit

struct FontPickerView: UIViewControllerRepresentable {
    
    @ObservedObject var themesViewModel: ThemeViewModel
    @Binding var selectedFont: UIFont?
    @Binding var isPresented: Bool // To manage dismissal
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UINavigationController {
        // Create a container view controller to hold the font picker and cancel button
        let navController = UINavigationController()
        
        // Create and configure the font picker
        let fontPicker = UIFontPickerViewController()
        fontPicker.delegate = context.coordinator
        
        // Add a "Done" button to the navigation bar
        fontPicker.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: context.coordinator,
            action: #selector(context.coordinator.dismissFontPicker)
        )
        
        // Set the font picker as the root view controller of the navigation controller
        navController.viewControllers = [fontPicker]
        return navController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No need to update, this is a static view controller
    }
    
    class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
        var parent: FontPickerView
        
        init(_ parent: FontPickerView) {
            self.parent = parent
        }
        
        @objc func dismissFontPicker() {
                parent.isPresented = false // Dismiss the font picker when Done is tapped
            }
        
        func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
            if let fontDescriptor = viewController.selectedFontDescriptor {
                let font = UIFont(descriptor: fontDescriptor, size: 30)
                let fontName = fontDescriptor.postscriptName ?? "System"
                parent.selectedFont = font
                parent.themesViewModel.setFontName(fontName)
                parent.themesViewModel.choose(Font(font))
            }
            parent.isPresented = false // Dismiss after selection
        }

        func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) {
            parent.isPresented = false // Dismiss when cancelled
        }
    }
}
