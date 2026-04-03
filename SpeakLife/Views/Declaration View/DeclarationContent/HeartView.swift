//
//  HeartView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/17/22.
//

import SwiftUI

struct HeartView: View {
    var body: some View {
           ZStack{
               Rectangle()
                   .frame(width: 50, height: 50, alignment: .center)
                   .foregroundColor(.red)
                   .cornerRadius(5)
               
               Circle()
                   .frame(width: 50, height: 50, alignment: .center)
                   .foregroundColor(.red)
                   .padding(.top, -50)
               
               Circle()
                   .frame(width: 50, height: 50, alignment: .center)
                   .foregroundColor(.red)
                   .padding(.trailing, -50)
           }.rotationEffect(Angle(degrees: -45))
       }
}
