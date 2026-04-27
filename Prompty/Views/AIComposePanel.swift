import SwiftUI

enum AIComposeMode {
    case build
    case edit

    var title: String { self == .edit ? "Edit with AI" : "Build with AI" }

    var subheading: String {
        self == .edit
            ? "I'll update the existing blocks based on your instruction."
            : "I'll structure it across all 10 blocks following the recommended flow."
    }

    var placeholder: String {
        self == .edit ? "What should I change?" : "Describe your task…"
    }

    var quickStarts: [String] {
        switch self {
        case .build:
            return [
                "Debug a flaky integration test",
                "Code review for a pull request",
                "Refactor a messy module",
                "Investigate a production incident"
            ]
        case .edit:
            return [
                "Tighten the tone",
                "Add stricter output format",
                "Sharpen the request",
                "Add a fallback rule"
            ]
        }
    }
}

struct AIComposePanel: View {
    let ai: PromptAI
    let mode: AIComposeMode
    let currentBlocks: [PromptBlock]
    let onClose: () -> Void
    let onGenerate: (DraftedPromptBlocks) -> Void
    let onRevert: ([PromptBlock]) -> Void

    @State private var idea: String = ""
    @State private var isLoading: Bool = false
    @State private var errorText: String?
    @State private var generationTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            transcriptView
            inputBar
        }
        .frame(width: 460)
        .frame(maxHeight: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.gray.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 32, x: 0, y: 12)
        .onAppear { focused = true }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image("AppleIntelligenceIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                Text(mode.title)
                    .font(.headline)
            }
            Spacer()

            if ai.hasConversation {
                Button {
                    ai.resetComposeConversation()
                    idea = ""
                    errorText = nil
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(.background.secondary, in: Circle())
                }
                .buttonStyle(.plain)
                .clickable()
                .help("Start a new conversation")
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.background.secondary, in: Circle())
            }
            .buttonStyle(.plain)
            .clickable()
        }
        .padding(16)
    }

    @ViewBuilder
    private var transcriptView: some View {
        if ai.transcript.isEmpty {
            initialContent
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(ai.transcript) { msg in
                            messageView(msg)
                                .id(msg.id)
                                .transition(.asymmetric(
                                    insertion: .scale(
                                        scale: 0.7,
                                        anchor: msg.role == .user ? .bottomTrailing : .bottomLeading
                                    )
                                    .combined(with: .offset(y: 24))
                                    .combined(with: .opacity),
                                    removal: .scale(scale: 0.9)
                                        .combined(with: .opacity)
                                ))
                        }
                        if let errorText {
                            Label(errorText, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                    .animation(.spring(response: 0.42, dampingFraction: 0.68), value: ai.transcript.count)
                }
                .onChange(of: ai.transcript.last?.id) { _, _ in
                    if let last = ai.transcript.last?.id {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: ai.streamedFields) { _, _ in
                    if let last = ai.transcript.last?.id {
                        withAnimation(.snappy(duration: 0.15)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var initialContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !ai.isAvailable {
                    unavailableNotice
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(mode.subheading)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(mode == .edit ? "Quick edits" : "Quick starts")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(mode.quickStarts, id: \.self) { text in
                            quickStartChip(text)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func messageView(_ msg: AIMessage) -> some View {
        switch msg.role {
        case .user:
            HStack {
                Spacer(minLength: 36)
                Text(msg.text)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
                    )
            }
        case .assistant:
            assistantMessage(msg)
        }
    }

    @ViewBuilder
    private func assistantMessage(_ msg: AIMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if msg.blocks.isEmpty && msg.isStreaming {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.mini)
                    Text("Thinking…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(PromptBlockKind.allCases) { kind in
                if let value = msg.blocks[kind],
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blockCard(kind: kind, value: value, streaming: msg.isStreaming)
                        .transition(.scale(scale: 0.85, anchor: .leading)
                            .combined(with: .opacity)
                            .combined(with: .offset(y: 8)))
                }
            }

            if !msg.isStreaming, let snapshot = msg.previousBlocks, msg.didApply {
                Button {
                    onRevert(snapshot)
                    if let idx = ai.transcript.firstIndex(where: { $0.id == msg.id }) {
                        ai.transcript[idx].didApply = false
                    }
                } label: {
                    Label("Undo this change", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.background.secondary, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.gray.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .clickable()
                .help("Restore the prompt to the state before this change")
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: msg.blocks.keys.count)
    }

    private func blockCard(kind: PromptBlockKind, value: String, streaming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(kind.title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            .foregroundStyle(streaming ? AnyShapeStyle(AIColors.gradient) : AnyShapeStyle(Color.secondary))

            markdownText(value)
                .font(.callout)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if idea.isEmpty {
                    Text(mode.placeholder)
                        .foregroundStyle(.tertiary)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextField("", text: $idea, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .focused($focused)
                    .lineLimit(1...5)
                    .disabled(isLoading)
                    .onKeyPress { press in
                        guard press.key == .return else { return .ignored }
                        if press.modifiers.contains(.shift) { return .ignored }
                        if canGenerate {
                            generate()
                            return .handled
                        }
                        return .ignored
                    }
            }

            Button(action: isLoading ? stop : generate) {
                ZStack {
                    Circle()
                        .fill(sendButtonFill)
                        .frame(width: 32, height: 32)
                    Image(systemName: isLoading ? "stop.fill" : "arrow.up")
                        .font(.system(size: isLoading ? 11 : 14, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .animation(.snappy(duration: 0.18), value: canGenerate)
                .animation(.snappy(duration: 0.18), value: isLoading)
            }
            .buttonStyle(.plain)
            .disabled(!isLoading && !canGenerate)
            .clickable()
            .help(isLoading ? "Stop generating" : "Send")
            .padding(.trailing, 4)
            .padding(.bottom, 4)
        }
        .padding(4)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.gray.opacity(0.18), lineWidth: 1)
        )
        .padding(16)
    }

    private var unavailableNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            Text(ai.unavailableReason ?? "Apple Intelligence unavailable.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func quickStartChip(_ text: String) -> some View {
        Button {
            idea = text
            focused = true
        } label: {
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .clickable()
    }

    private var canGenerate: Bool {
        ai.isAvailable && !idea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sendButtonFill: Color {
        if isLoading { return Color.primary }
        return canGenerate ? Color.accentColor : Color.secondary.opacity(0.3)
    }

    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
        } else {
            Text(text)
        }
    }

    private func generate() {
        let trimmed = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ai.isAvailable, !trimmed.isEmpty else { return }
        isLoading = true
        errorText = nil
        idea = ""

        generationTask = Task {
            defer {
                Task { @MainActor in
                    isLoading = false
                    generationTask = nil
                }
            }
            do {
                let final: DraftedPromptBlocks
                switch mode {
                case .build:
                    final = try await ai.draftStreaming(from: trimmed)
                case .edit:
                    final = try await ai.editStreaming(
                        currentBlocks: currentBlocks,
                        instruction: trimmed
                    )
                }
                onGenerate(final)
            } catch is CancellationError {
                // User stopped — keep the partial output visible, don't apply to doc.
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func stop() {
        generationTask?.cancel()
    }
}
