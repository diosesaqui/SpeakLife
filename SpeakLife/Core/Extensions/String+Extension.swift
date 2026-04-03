//
//  String+Extension.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 3/19/22.
//

import Foundation

extension StringProtocol {
    var firstUppercased: String { prefix(1).uppercased() + dropFirst() }
    var firstCapitalized: String { prefix(1).capitalized + dropFirst() }
}
