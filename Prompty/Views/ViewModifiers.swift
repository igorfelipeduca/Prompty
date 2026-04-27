import SwiftUI

extension View {
    /// Show a pointing-hand cursor on hover. Apply to interactive elements (buttons, links, cards).
    func clickable() -> some View {
        self.pointerStyle(.link)
    }
}
