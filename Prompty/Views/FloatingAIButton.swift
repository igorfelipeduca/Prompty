import SwiftUI

struct FloatingAIButton: View {
    let ai: PromptAI
    let mode: AIComposeMode
    let onTap: () -> Void
    let onDismiss: () -> Void

    @State private var hovered: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Image("AppleIntelligenceIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)

                    Text(mode.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .contentTransition(.identity)
                }
                .padding(.horizontal, 18)
                .frame(height: 48)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.18)).interactive(), in: Capsule())
                .contentShape(Capsule())
                .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)
                .shadow(color: Color.accentColor.opacity(0.25), radius: 22, x: 0, y: 0)
                .scaleEffect(hovered ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .clickable()
            .help(ai.isAvailable
                  ? "\(mode.title) (Apple Intelligence)"
                  : (ai.unavailableReason ?? "Apple Intelligence unavailable"))

            if hovered {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.black.opacity(0.85), in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                }
                .buttonStyle(.plain)
                .clickable()
                .offset(x: -6, y: -6)
                .transition(.scale.combined(with: .opacity))
                .help("Hide button")
            }
        }
        .onHover { hovered = $0 }
        .animation(.snappy(duration: 0.15), value: hovered)
    }
}
