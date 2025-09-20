//
//  SelectionFeedback.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/14/22.
//

import SwiftUI

final class Selection {
    
    static var shared = Selection()
    
    private var generator = UISelectionFeedbackGenerator()
    
    private init() {
        DispatchQueue.main.async { [weak self] in
            self?.generator.prepare()
        }
    }
    
    func selectionFeedback() {
        DispatchQueue.main.async {  [weak self] in
            self?.generator.selectionChanged()
        }
    }
}


