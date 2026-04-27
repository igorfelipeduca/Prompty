import SwiftUI
import AppKit

struct OnboardingView: View {
    let ai: PromptAI
    let onFinish: () -> Void

    @State private var page: Int = 0
    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 48)
                .padding(.top, 56)

            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 640, height: 540)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0: WelcomePage()
        case 1: HowItWorksPage()
        case 2: AppleIntelligencePage(ai: ai)
        default: FollowPage()
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Skip") { finish() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .opacity(page == pageCount - 1 ? 0 : 1)
                .clickable()

            Spacer()

            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { idx in
                    Circle()
                        .fill(idx == page ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 7, height: 7)
                        .animation(.snappy(duration: 0.18), value: page)
                }
            }

            Spacer()

            if page > 0 {
                Button("Back") {
                    withAnimation(.snappy(duration: 0.2)) { page -= 1 }
                }
                .clickable()
            }

            if page < pageCount - 1 {
                Button("Continue") {
                    withAnimation(.snappy(duration: 0.2)) { page += 1 }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .clickable()
            } else {
                Button("Get Started") { finish() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .clickable()
            }
        }
    }

    private func finish() { onFinish() }
}

// MARK: - Welcome

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 22) {
            Image("AppLogo")
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24))

            VStack(spacing: 10) {
                Text("Welcome to Prompty")
                    .font(.system(.largeTitle, design: .default).weight(.semibold))
                Text("Compose Claude Code prompts that won't drift.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 10) {
                bullet("rectangle.stack", "10-block flow recommended by the Claude Code team")
                bullet("checklist", "Toggle blocks, auto-wrap context tags, live preview")
                bullet("sparkles", "Apple Intelligence drafts and polishes for you")
            }
            .padding(.top, 6)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - How it works

private struct HowItWorksPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("How prompts stay stable")
                    .font(.system(.title, design: .default).weight(.semibold))
                Text("Stable context first. Volatile request late. Output contract last.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(PromptBlockKind.allCases.enumerated()), id: \.element) { index, kind in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .trailing)
                            Image(systemName: kind.symbol)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 22, height: 22)
                                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(kind.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(kind.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 320)
        }
    }
}

// MARK: - Apple Intelligence

private struct AppleIntelligencePage: View {
    let ai: PromptAI

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Image("AppleIntelligenceIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                    Text("Apple Intelligence built in")
                        .font(.system(.title, design: .default).weight(.semibold))
                }
                Text("On-device. No API key. No usage limits.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                feature("wand.and.stars",
                        "Compose from an idea",
                        "Describe what you want Claude to help with. Get all 10 blocks drafted automatically.")
                feature("sparkles",
                        "Polish any block",
                        "Tighten language, sharpen specifics, keep your intent.")
                feature("lock.shield",
                        "Stays on your Mac",
                        "Apple's on-device foundation model handles everything locally.")
            }

            statusPill
                .padding(.top, 6)

            Spacer()
        }
    }

    private func feature(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 26, height: 26)
                .background(Color.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ai.isAvailable ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(ai.isAvailable
                 ? "Apple Intelligence is ready on this Mac"
                 : (ai.unavailableReason ?? "Apple Intelligence unavailable on this Mac"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Follow

private struct FollowPage: View {
    @State private var didFollow = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack(alignment: .bottomTrailing) {
                Image("TwitterPFP")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.gray.opacity(0.18), lineWidth: 1)
                    )
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().strokeBorder(Color.white, lineWidth: 2)
                        )
                    Text("𝕏")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: 4, y: 4)
            }

            VStack(spacing: 8) {
                Text("Built by @ducaswtf")
                    .font(.system(.title, design: .default).weight(.semibold))
                Text("Follow for more tools, prompts, and Claude Code tips.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            VStack(spacing: 10) {
                Button {
                    if let url = URL(string: "https://x.com/ducaswtf") {
                        NSWorkspace.shared.open(url)
                        didFollow = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("𝕏")
                            .font(.system(size: 16, weight: .bold))
                        Text(didFollow ? "Opened in browser" : "Follow @ducaswtf on X")
                            .font(.headline)
                    }
                    .frame(width: 280, height: 44)
                    .foregroundStyle(.white)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .clickable()

                Text("x.com/ducaswtf")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
