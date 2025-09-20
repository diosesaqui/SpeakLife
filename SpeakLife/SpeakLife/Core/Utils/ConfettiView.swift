//
//  ConfettiView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 3/12/24.
//

import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 1)) // Ensure the view is wide enough
            view.clipsToBounds = false // Avoid clipping the confetti
               
        
        // Confetti pieces
        let confettiTypes = ["🎉", "🎊", "🎈", "❤️", "🌟", "✝️"]
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: view.frame.size.width / 2, y: -10) // Start just above the view's bounds to avoid cutting off
               emitter.emitterSize = CGSize(width: view.frame.size.width, height: 1)
               
        
        emitter.emitterCells = confettiTypes.map { confettiType in
            let cell = CAEmitterCell()
            cell.birthRate = 6
            cell.lifetime = 14.0
            cell.velocity = CGFloat(300)
            cell.velocityRange = CGFloat(100)
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 4
            cell.spin = 3.5
            cell.spinRange = 1.0
            cell.scaleRange = 0.25
            cell.scaleSpeed = -0.1
            cell.contents = confettiType.image().cgImage
            return cell
        }
        
        view.layer.addSublayer(emitter)
        emitter.birthRate = 0 // Initially turned off
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            emitter.birthRate = 1 // Turn on after 10 seconds
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            emitter.birthRate = 0 // Turn off after 15 seconds
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension String {
    func image() -> UIImage {
         let size = CGSize(width: 40, height: 40) // Increase the size to ensure the emoji isn't cut off
         UIGraphicsBeginImageContextWithOptions(size, false, 0)
         UIColor.clear.set()
         let rect = CGRect(x: 5, y: 5, width: 30, height: 30) // Adjust drawing area within the context
         (self as NSString).draw(in: rect, withAttributes: [.font: UIFont.systemFont(ofSize: 30)]) // Ensure the emoji fits within the adjusted rect
         let image = UIGraphicsGetImageFromCurrentImageContext()!
         UIGraphicsEndImageContext()
         return image
     }
}
