//
//  AdaptiveSheetModifier.swift
//  SpeakLife
//
//  Presents a fullScreenCover on iPad and a standard bottom sheet on iPhone.
//  This prevents the iPad "form sheet" constraint (~540pt wide) that leaves
//  black bars on either side of modal content.
//

import SwiftUI

struct AdaptiveSheetModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @Binding var item: Item?
    let isIPad: Bool
    let content: (Item) -> SheetContent

    func body(content outerContent: Content) -> some View {
        if isIPad {
            outerContent
                .fullScreenCover(item: $item) { item in
                    content(item)
                }
        } else {
            outerContent
                .sheet(item: $item) { item in
                    content(item)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
        }
    }
}
