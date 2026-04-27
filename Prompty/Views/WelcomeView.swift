import SwiftUI

struct WelcomeView: View {
    let ai: PromptAI
    let onTemplate: (PromptTemplate) -> Void
    let onAICompose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                aiCard
                templatesSection
            }
            .padding(40)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 16) {
            Image("AppLogo")
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text("Compose better prompts")
                    .font(.system(.largeTitle, design: .default).weight(.semibold))
                Text("Stable context first, volatile request late, output contract last.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aiCard: some View {
        Button(action: onAICompose) {
            HStack(alignment: .center, spacing: 16) {
                Image("AppleIntelligenceIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .frame(width: 56, height: 56)
                    .background(.background.tertiary, in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Compose with Apple Intelligence")
                        .font(.headline)
                    Text(ai.isAvailable
                         ? "Describe your idea, get all 10 blocks drafted on-device."
                         : (ai.unavailableReason ?? "Apple Intelligence unavailable."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if ai.isAvailable {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.gray.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!ai.isAvailable)
        .opacity(ai.isAvailable ? 1.0 : 0.7)
        .clickable()
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Or start from a template")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), spacing: 12)],
                spacing: 12
            ) {
                ForEach(PromptTemplate.allCases) { template in
                    TemplateCard(template: template) {
                        onTemplate(template)
                    }
                }
            }
        }
    }
}

private struct TemplateCard: View {
    let template: PromptTemplate
    let onTap: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.label)
                        .font(.subheadline.weight(.semibold))
                    Text(template.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                .background.secondary.opacity(hovered ? 1.0 : 0.6),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        hovered ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.18),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.snappy(duration: 0.12), value: hovered)
        .clickable()
    }

    private var icon: String {
        switch template {
        case .empty:            return "doc"
        case .full:             return "rectangle.stack"
        case .minimal:          return "rectangle"
        case .codeReview:       return "checklist"
        case .bugInvestigation: return "ladybug"
        }
    }
}
