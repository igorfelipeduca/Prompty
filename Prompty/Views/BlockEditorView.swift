import SwiftUI

struct BlockEditorView: View {
    let block: PromptBlock
    let siblingBlocks: [PromptBlock]
    let onChange: (PromptBlock) -> Void

    @Environment(PromptAI.self) private var ai
    @State private var isExpanded: Bool = true
    @State private var isPolishing: Bool = false
    @State private var isSuggesting: Bool = false
    @State private var streamingText: String?
    @State private var aiError: String?
    @State private var hovered: Bool = false

    private var charCount: Int { block.content.count }
    private var hasContent: Bool {
        !block.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                editor
            }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .opacity(block.enabled ? 1.0 : 0.5)
        .onHover { hovered = $0 }
        .animation(.snappy(duration: 0.12), value: hovered)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: block.kind.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(block.enabled ? Color.accentColor : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    (block.enabled ? Color.accentColor : Color.secondary).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 7)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(block.kind.title)
                    .font(.headline)
                Text(block.kind.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if hasContent {
                Text("\(charCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Toggle("", isOn: Binding(
                get: { block.enabled },
                set: { newValue in
                    var copy = block
                    copy.enabled = newValue
                    onChange(copy)
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()

            Button {
                withAnimation(.snappy(duration: 0.18)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .clickable()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            ZStack(alignment: .topLeading) {
                if !hasContent && streamingText == nil {
                    Text(block.kind.placeholder)
                        .font(.system(.body))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .allowsHitTesting(false)
                }

                if let stream = streamingText {
                    streamingOverlay(stream)
                } else {
                    TextEditor(text: Binding(
                        get: { block.content },
                        set: { newValue in
                            var copy = block
                            copy.content = newValue
                            onChange(copy)
                        }
                    ))
                    .font(.system(.body))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 80)
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 14)

            footer
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if block.kind.supportsWrapper, let tag = block.kind.wrapperTag {
                Toggle(isOn: Binding(
                    get: { block.useWrapper },
                    set: { newValue in
                        var copy = block
                        copy.useWrapper = newValue
                        onChange(copy)
                    }
                )) {
                    Text("<\(tag)>")
                        .font(.caption.monospaced())
                }
                .toggleStyle(.checkbox)
                .controlSize(.small)
            }

            if let aiError {
                Label(aiError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }

            Spacer()

            if ai.isAvailable {
                if hasContent {
                    aiButton(
                        title: "Polish",
                        symbol: "sparkles",
                        isLoading: isPolishing,
                        action: polish
                    )
                } else {
                    aiButton(
                        title: "Suggest",
                        symbol: "wand.and.stars",
                        isLoading: isSuggesting,
                        action: suggest
                    )
                }
            }

            if hasContent {
                Button {
                    update { $0.content = "" }
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .clickable()
            }
        }
    }

    private func aiButton(title: String, symbol: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: symbol)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                Text(title)
            }
            .font(.caption.weight(.medium))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .help("Use Apple Intelligence")
        .clickable()
    }

    @ViewBuilder
    private func streamingOverlay(_ stream: String) -> some View {
        if stream.isEmpty {
            // Waiting for first partial — shimmer over old content
            Text(block.content.isEmpty ? "Generating…" : block.content)
                .font(.system(.body))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .aiShimmer(active: true)
        } else {
            Text(stream)
                .font(.system(.body))
                .foregroundStyle(AIColors.gradient)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                .textSelection(.enabled)
        }
    }

    private func update(_ transform: (inout PromptBlock) -> Void) {
        var copy = block
        transform(&copy)
        onChange(copy)
    }

    private func polish() {
        aiError = nil
        isPolishing = true
        streamingText = ""
        Task {
            defer {
                isPolishing = false
                streamingText = nil
            }
            do {
                let polished = try await ai.polishStreaming(
                    kind: block.kind,
                    content: block.content
                ) { partial in
                    streamingText = partial
                }
                guard !polished.isEmpty else { return }
                update { $0.content = polished }
            } catch {
                aiError = "Polish failed"
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    aiError = nil
                }
            }
        }
    }

    private func suggest() {
        aiError = nil
        isSuggesting = true
        streamingText = ""
        Task {
            defer {
                isSuggesting = false
                streamingText = nil
            }
            do {
                let suggested = try await ai.suggestStreaming(
                    kind: block.kind,
                    otherBlocks: siblingBlocks
                ) { partial in
                    streamingText = partial
                }
                guard !suggested.isEmpty else { return }
                update { $0.content = suggested }
            } catch {
                aiError = "Suggest failed"
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    aiError = nil
                }
            }
        }
    }
}
