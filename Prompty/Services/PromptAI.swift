import Foundation
import Observation
import FoundationModels

@Generable
struct DraftedPromptBlocks {
    @Guide(description: "Role, environment, and high-level goal. Sets the frame. 2-3 sentences.")
    var taskContext: String

    @Guide(description: "Voice, tone, brand personality. Plain instruction, separated from hard rules.")
    var tone: String

    @Guide(description: "Background documents or context placeholders the model should reference. Use {{PLACEHOLDERS}} for runtime-injected docs.")
    var background: String

    @Guide(description: "Hard constraints as a bulleted list using - prefixes. Include do/don't items and a fallback for ambiguity. 4-8 bullets.")
    var rules: String

    @Guide(description: "1-3 strong examples of desired input/output behavior. Use User: / Assistant: format.")
    var examples: String

    @Guide(description: "Placeholder for prior conversation turns, usually {{HISTORY}} or a short summary instruction.")
    var history: String

    @Guide(description: "The exact ask the model should answer. Often {{REQUEST}} or a literal question.")
    var request: String

    @Guide(description: "Instruction to reason carefully but keep reasoning private. One sentence.")
    var reasoning: String

    @Guide(description: "Strict output contract: JSON schema, XML tags, or markdown structure. Specific and concrete.")
    var output: String
}

@MainActor
@Observable
final class PromptAI {
    enum Availability: Equatable {
        case checking
        case available
        case unavailable(String)
    }

    private(set) var availability: Availability = .checking
    var streamedFields: [PromptBlockKind: String] = [:]
    var transcript: [AIMessage] = []
    var hasConversation: Bool { !transcript.isEmpty }

    var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    var unavailableReason: String? {
        if case .unavailable(let reason) = availability { return reason }
        return nil
    }

    private var composeSession: LanguageModelSession?

    static let largeOptions = GenerationOptions(temperature: 0.7, maximumResponseTokens: 4096)
    static let polishOptions = GenerationOptions(temperature: 0.5, maximumResponseTokens: 2048)
    static let suggestOptions = GenerationOptions(temperature: 0.7, maximumResponseTokens: 2048)

    private var composeInstructions: String { """
        You are a prompt engineer specialized in writing prompts for Claude Code.

        You build and revise structured Claude prompts following this block flow:
        stable context first, volatile request late, output contract last.

        REQUIREMENTS for every block you choose to write:
        - Be substantive and detailed. Aim for 4–8 full sentences per text block, never \
          one-liners. Pack in concrete specifics: file paths, exact tool names, expected \
          formats, edge cases, fallback behavior.
        - Use {{PLACEHOLDERS}} for runtime values like background docs, history, request.
        - Rules block: 6–10 bulleted constraints with - prefix. Cover do/don't, fallback \
          for ambiguity, and what to never assume.
        - Examples block: 1–3 concrete worked examples in User: / Assistant: format.
        - Output block: a strict contract — exact JSON schema, XML tags, or markdown \
          structure with field names. Be specific.

        TARGETED EDITS — critical:
        When the user names specific blocks ("improve the tone", "make rules stricter", \
        "tighten the output format"), ONLY return new content for those blocks. Leave \
        every other field as an empty string ("") so the existing content is preserved.

        When the user gives a generic instruction ("make it better", "rewrite this", \
        "build me a prompt"), fill in every block with substantive content.

        An empty string for a field always means "leave the existing block unchanged".

        Match the no-fluff tone of senior engineers. Skip preamble and apologies.

        You iterate across turns — when the user follows up, refine the prior output \
        based on the conversation rather than starting fresh.
        """ }

    init() { refresh() }

    func refresh() {
        let model = SystemLanguageModel.default
        if case .available = model.availability {
            availability = .available
        } else {
            availability = .unavailable(
                "Apple Intelligence is unavailable. Turn it on in System Settings → Apple Intelligence & Siri, or wait for the on-device model to finish downloading."
            )
        }
    }

    private func sharedComposeSession() -> LanguageModelSession {
        if let composeSession { return composeSession }
        let s = LanguageModelSession(instructions: composeInstructions)
        composeSession = s
        return s
    }

    func resetComposeConversation() {
        composeSession = nil
        streamedFields = [:]
        transcript = []
    }

    func draftStreaming(from idea: String) async throws -> DraftedPromptBlocks {
        streamedFields = [:]
        let session = sharedComposeSession()

        let userMsg = AIMessage(role: .user, text: idea)
        transcript.append(userMsg)
        let assistantMsg = AIMessage(role: .assistant, text: "", isStreaming: true)
        transcript.append(assistantMsg)
        let assistantIndex = transcript.count - 1

        let stream = session.streamResponse(
            to: """
            Build a new structured Claude Code prompt for this idea:

            \(idea)

            Return the full blocks. Be detailed and specific in every field.
            """,
            generating: DraftedPromptBlocks.self,
            options: Self.largeOptions
        )

        do {
            var last: DraftedPromptBlocks.PartiallyGenerated?
            for try await snapshot in stream {
                if Task.isCancelled {
                    transcript[assistantIndex].isStreaming = false
                    throw CancellationError()
                }
                let partial = snapshot.content
                applyPartial(partial)
                transcript[assistantIndex].blocks = streamedFields
                last = partial
            }
            transcript[assistantIndex].isStreaming = false

            return DraftedPromptBlocks(
                taskContext: last?.taskContext ?? "",
                tone:        last?.tone ?? "",
                background:  last?.background ?? "",
                rules:       last?.rules ?? "",
                examples:    last?.examples ?? "",
                history:     last?.history ?? "",
                request:     last?.request ?? "",
                reasoning:   last?.reasoning ?? "",
                output:      last?.output ?? ""
            )
        } catch {
            transcript[assistantIndex].isStreaming = false
            throw error
        }
    }

    func editStreaming(currentBlocks: [PromptBlock], instruction: String) async throws -> DraftedPromptBlocks {
        streamedFields = [:]
        let session = sharedComposeSession()

        let current = currentBlocks
            .filter { $0.enabled && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { "## \($0.kind.title)\n\($0.content)" }
            .joined(separator: "\n\n")

        let userMsg = AIMessage(role: .user, text: instruction)
        transcript.append(userMsg)
        let assistantMsg = AIMessage(
            role: .assistant,
            text: "",
            isStreaming: true,
            previousBlocks: currentBlocks
        )
        transcript.append(assistantMsg)
        let assistantIndex = transcript.count - 1

        let stream = session.streamResponse(
            to: """
            Revise this prompt.

            Current prompt:
            \(current.isEmpty ? "(empty)" : current)

            Requested change: \(instruction)

            Only return new content for the blocks the user asked you to change. \
            Leave every other field as an empty string (""). An empty field means \
            "keep the existing content unchanged". Be detailed and specific in the \
            blocks you do change — never collapse them to a single line.
            """,
            generating: DraftedPromptBlocks.self,
            options: Self.largeOptions
        )

        do {
            var last: DraftedPromptBlocks.PartiallyGenerated?
            for try await snapshot in stream {
                if Task.isCancelled {
                    transcript[assistantIndex].isStreaming = false
                    throw CancellationError()
                }
                let partial = snapshot.content
                applyPartial(partial)
                transcript[assistantIndex].blocks = streamedFields
                last = partial
            }
            transcript[assistantIndex].isStreaming = false

            return DraftedPromptBlocks(
                taskContext: last?.taskContext ?? "",
                tone:        last?.tone ?? "",
                background:  last?.background ?? "",
                rules:       last?.rules ?? "",
                examples:    last?.examples ?? "",
                history:     last?.history ?? "",
                request:     last?.request ?? "",
                reasoning:   last?.reasoning ?? "",
                output:      last?.output ?? ""
            )
        } catch {
            transcript[assistantIndex].isStreaming = false
            throw error
        }
    }

    private func applyPartial(_ partial: DraftedPromptBlocks.PartiallyGenerated) {
        var next = streamedFields
        if let v = partial.taskContext { next[.taskContext] = v }
        if let v = partial.tone        { next[.tone]        = v }
        if let v = partial.background  { next[.background]  = v }
        if let v = partial.rules       { next[.rules]       = v }
        if let v = partial.examples    { next[.examples]    = v }
        if let v = partial.history     { next[.history]     = v }
        if let v = partial.request     { next[.request]     = v }
        if let v = partial.reasoning   { next[.reasoning]   = v }
        if let v = partial.output      { next[.output]      = v }
        streamedFields = next
    }

    func polishStreaming(
        kind: PromptBlockKind,
        content: String,
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let session = LanguageModelSession(instructions: """
            You polish prompt blocks for Claude Code. Keep the user's intent. Make the \
            language tighter, clearer, and more specific. Expand vague points into \
            concrete ones. Output ONLY the polished text. No preamble. No explanation. \
            No markdown fences unless the original had them.
            """)
        let stream = session.streamResponse(
            to: """
            Block type: \(kind.title)
            Purpose: \(kind.subtitle)

            Current content:
            \(content)

            Polished version:
            """,
            options: Self.polishOptions
        )

        var last = ""
        for try await snapshot in stream {
            let text = snapshot.content
            onPartial(text)
            last = text
        }
        return last.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func suggestStreaming(
        kind: PromptBlockKind,
        otherBlocks: [PromptBlock],
        onPartial: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let context = otherBlocks
            .filter { $0.enabled && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.kind != kind }
            .map { "## \($0.kind.title)\n\($0.content)" }
            .joined(separator: "\n\n")

        let session = LanguageModelSession(instructions: """
            You write a single prompt block for Claude Code based on the surrounding \
            blocks. Write a substantive block — 2-5 sentences with concrete details. \
            Output ONLY the new block content. No headings. No preamble.
            """)
        let stream = session.streamResponse(
            to: """
            Existing blocks:
            \(context.isEmpty ? "(none yet)" : context)

            Write the \(kind.title) block.
            Purpose: \(kind.subtitle).
            """,
            options: Self.suggestOptions
        )

        var last = ""
        for try await snapshot in stream {
            let text = snapshot.content
            onPartial(text)
            last = text
        }
        return last.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
