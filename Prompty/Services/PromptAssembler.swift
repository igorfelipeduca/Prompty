import Foundation

enum PromptAssembler {
    nonisolated static func assemble(_ blocks: [PromptBlock]) -> String {
        let parts = blocks
            .filter { $0.enabled }
            .compactMap(format)
        return parts.joined(separator: "\n\n")
    }

    /// Split the prompt into Claude CLI inputs: everything except `Current Request` becomes
    /// the system prompt; `Current Request` becomes the first user message. This makes Claude
    /// operate UNDER the assembled context and act on the request, instead of treating the
    /// whole structured thing as "help me build a prompt."
    nonisolated static func assembleForCLI(_ blocks: [PromptBlock]) -> (systemPrompt: String, userMessage: String) {
        let enabled = blocks.filter { $0.enabled }
        let systemBlocks = enabled.filter { $0.kind != .request }
        let requestBlock = enabled.first { $0.kind == .request }

        let systemPrompt = systemBlocks.compactMap(format).joined(separator: "\n\n")
        let userMessage = requestBlock?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return (systemPrompt, userMessage)
    }

    nonisolated private static func format(_ block: PromptBlock) -> String? {
        let trimmed = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if block.useWrapper, let tag = block.kind.wrapperTag {
            return "<\(tag)>\n\(trimmed)\n</\(tag)>"
        }
        return trimmed
    }
}
