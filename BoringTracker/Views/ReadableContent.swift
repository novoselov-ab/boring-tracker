import SwiftUI

extension View {
    @ViewBuilder
    func readableContent() -> some View {
        // Device identity is stable across resizing; size-class branching would
        // replace stateful forms when an iPad window becomes narrow.
        if UIDevice.current.userInterfaceIdiom == .pad {
            self
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
        } else {
            self
        }
    }
}
