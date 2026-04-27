import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @State private var selection: PromptDocument?
    @State private var showAICompose: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var ai = PromptAI()
    @AppStorage("aiButtonHidden") private var aiButtonHidden: Bool = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            if let doc = selection {
                ComposerView(document: doc)
            } else {
                WelcomeView(
                    ai: ai,
                    onTemplate: { template in
                        create(from: template)
                    },
                    onAICompose: {
                        showAICompose = true
                    }
                )
            }
        }
        .frame(minWidth: 1000, minHeight: 660)
        .environment(ai)
        .overlay(alignment: .bottomTrailing) {
            ZStack(alignment: .bottomTrailing) {
                if showAICompose {
                    AIComposePanel(
                        ai: ai,
                        mode: composeMode,
                        currentBlocks: selection?.blocks ?? [],
                        onClose: {
                            withAnimation(.snappy(duration: 0.28)) { showAICompose = false }
                        },
                        onGenerate: { drafted in
                            apply(drafted: drafted)
                        },
                        onRevert: { snapshot in
                            revert(to: snapshot)
                        }
                    )
                    .padding(.trailing, 22)
                    .padding(.vertical, 22)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else if !aiButtonHidden {
                    FloatingAIButton(
                        ai: ai,
                        mode: composeMode,
                        onTap: {
                            withAnimation(.snappy(duration: 0.28)) { showAICompose = true }
                        },
                        onDismiss: {
                            withAnimation(.snappy(duration: 0.28)) { aiButtonHidden = true }
                        }
                    )
                    .padding(.trailing, 22)
                    .padding(.bottom, 22)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(ai: ai) {
                hasOnboarded = true
                showOnboarding = false
            }
            .interactiveDismissDisabled(true)
        }
        .task {
            ai.refresh()
            if !hasOnboarded {
                showOnboarding = true
            }
        }
    }

    private var composeMode: AIComposeMode {
        selection != nil ? .edit : .build
    }

    private func create(from template: PromptTemplate) {
        let doc = PromptDocument(name: template.defaultName, blocks: template.makeBlocks())
        context.insert(doc)
        try? context.save()
        selection = doc
    }

    private func apply(drafted: DraftedPromptBlocks) {
        let placeholders: Set<String> = ["", "Untitled Prompt", "New Prompt"]
        let updates = nonEmptyUpdates(from: drafted)

        if let existing = selection {
            var current = existing.blocks
            for (kind, content) in updates {
                if let idx = current.firstIndex(where: { $0.kind == kind }) {
                    current[idx].content = content
                    if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        current[idx].enabled = true
                    }
                }
            }
            existing.blocks = current
            if placeholders.contains(existing.name) {
                existing.name = "AI Draft"
            }
            try? context.save()
        } else {
            let blocks: [PromptBlock] = [
                .init(kind: .taskContext, content: drafted.taskContext),
                .init(kind: .tone,        content: drafted.tone),
                .init(kind: .background,  content: drafted.background),
                .init(kind: .rules,       content: drafted.rules),
                .init(kind: .examples,    content: drafted.examples),
                .init(kind: .history,     content: drafted.history),
                .init(kind: .request,     content: drafted.request),
                .init(kind: .reasoning,   content: drafted.reasoning),
                .init(kind: .output,      content: drafted.output),
                .init(kind: .prefill,     enabled: false),
            ]
            let doc = PromptDocument(name: "AI Draft", blocks: blocks)
            context.insert(doc)
            try? context.save()
            selection = doc
        }
    }

    private func nonEmptyUpdates(from drafted: DraftedPromptBlocks) -> [(PromptBlockKind, String)] {
        let candidates: [(PromptBlockKind, String)] = [
            (.taskContext, drafted.taskContext),
            (.tone,        drafted.tone),
            (.background,  drafted.background),
            (.rules,       drafted.rules),
            (.examples,    drafted.examples),
            (.history,     drafted.history),
            (.request,     drafted.request),
            (.reasoning,   drafted.reasoning),
            (.output,      drafted.output),
        ]
        return candidates.filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func revert(to snapshot: [PromptBlock]) {
        guard let existing = selection else { return }
        existing.blocks = snapshot
        try? context.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PromptDocument.self, inMemory: true)
}
