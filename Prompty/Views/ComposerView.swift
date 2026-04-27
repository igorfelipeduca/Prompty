import SwiftUI

struct ComposerView: View {
    @Bindable var document: PromptDocument
    @Environment(PromptAI.self) private var ai
    @State private var showPreview: Bool = true
    @State private var copied: Bool = false
    @State private var showHandoffSheet: Bool = false

    var body: some View {
        HSplitView {
            blockList
                .frame(minWidth: 440, idealWidth: 580)

            if showPreview {
                PreviewView(document: document)
                    .frame(minWidth: 360, idealWidth: 460)
            }
        }
        .sheet(isPresented: $showHandoffSheet) {
            HandoffSheet(
                blocks: document.blocks,
                onClose: { showHandoffSheet = false }
            )
        }
        .navigationTitle(document.name)
        .toolbar {
            ToolbarItem {
                Menu {
                    ForEach(PromptTemplate.allCases) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            Label(template.label, systemImage: icon(for: template))
                        }
                    }
                } label: {
                    Label("Replace", systemImage: "rectangle.stack")
                }
                .help("Replace blocks with a template")
                .clickable()
            }

            ToolbarItem {
                Button {
                    withAnimation(.snappy) { showPreview.toggle() }
                } label: {
                    Label(showPreview ? "Hide Preview" : "Show Preview",
                          systemImage: "rectangle.righthalf.filled")
                }
                .clickable()
            }

            ToolbarItem {
                Button {
                    PasteboardHelper.copy(document.assembledPrompt)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .help("Copy assembled prompt to clipboard")
                .disabled(document.assembledPrompt.isEmpty)
                .clickable()
            }

            ToolbarItem {
                Button {
                    showHandoffSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image("ClaudeMark")
                            .renderingMode(.original)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                        Text("Hand off to Claude")
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.85, green: 0.45, blue: 0.27))
                .help("Copy prompt and open Claude")
                .disabled(document.assembledPrompt.isEmpty)
                .clickable()
            }
        }
    }

    private var blockList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                header

                ForEach(document.blocks) { block in
                    BlockEditorView(
                        block: block,
                        siblingBlocks: document.blocks
                    ) { updated in
                        document.updateBlock(id: updated.id) { current in
                            current = updated
                        }
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .background(.background.tertiary)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Untitled Prompt", text: $document.name)
                .textFieldStyle(.plain)
                .font(.system(.largeTitle).weight(.semibold))

            HStack(alignment: .firstTextBaseline) {
                Text("Stable context first, volatile request late, output contract last.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                statBadge
            }
        }
        .padding(.bottom, 10)
    }

    private var statBadge: some View {
        Text("\(document.characterCount) chars")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.background.secondary, in: Capsule())
    }

    private func icon(for template: PromptTemplate) -> String {
        switch template {
        case .empty:            return "doc"
        case .full:             return "rectangle.stack"
        case .minimal:          return "rectangle"
        case .codeReview:       return "checklist"
        case .bugInvestigation: return "ladybug"
        }
    }

    private func applyTemplate(_ template: PromptTemplate) {
        document.blocks = template.makeBlocks()
        let placeholders: Set<String> = ["", "Untitled Prompt", "New Prompt", "AI Draft"]
        if placeholders.contains(document.name) {
            document.name = template.defaultName
        }
    }
}
