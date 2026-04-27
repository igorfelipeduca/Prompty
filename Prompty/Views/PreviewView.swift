import SwiftUI

struct PreviewView: View {
    @Bindable var document: PromptDocument
    @State private var copied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                if document.assembledPrompt.isEmpty {
                    emptyState
                } else {
                    Text(document.assembledPrompt)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            }
        }
        .background(.background)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Preview")
                    .font(.headline)
                Text("\(document.characterCount) chars · \(wordCount) words · \(approxTokens) ~tokens")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
            .disabled(document.assembledPrompt.isEmpty)
            .clickable()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Your assembled prompt will appear here")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Enable blocks and add content on the left.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var wordCount: Int {
        document.assembledPrompt
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }

    private var approxTokens: Int {
        max(1, document.characterCount / 4)
    }
}

enum PasteboardHelper {
    static func copy(_ text: String) {
        #if canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
    }
}
