import Foundation

enum PromptBlockKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case taskContext
    case tone
    case background
    case rules
    case examples
    case history
    case request
    case reasoning
    case output
    case prefill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .taskContext: return "Task Context"
        case .tone:        return "Tone"
        case .background:  return "Background & Sources"
        case .rules:       return "Rules"
        case .examples:    return "Examples"
        case .history:     return "Conversation History"
        case .request:     return "Current Request"
        case .reasoning:   return "Reasoning Instruction"
        case .output:      return "Output Format"
        case .prefill:     return "Assistant Prefill"
        }
    }

    var subtitle: String {
        switch self {
        case .taskContext: return "Role, job, environment, high-level goal"
        case .tone:        return "Voice, style, brand personality"
        case .background:  return "Source docs, retrieved chunks, facts"
        case .rules:       return "Constraints, do/don't, fallback behavior"
        case .examples:    return "1–3 strong examples of desired behavior"
        case .history:     return "Prior turns or compact summary"
        case .request:     return "The exact ask the model must answer"
        case .reasoning:   return "Tell model to reason carefully before answering"
        case .output:      return "JSON / schema / tags / Markdown rules"
        case .prefill:     return "Optional assistant prefix or partial answer"
        }
    }

    var symbol: String {
        switch self {
        case .taskContext: return "person.crop.circle"
        case .tone:        return "waveform"
        case .background:  return "doc.text"
        case .rules:       return "list.bullet.rectangle"
        case .examples:    return "sparkles"
        case .history:     return "bubble.left.and.bubble.right"
        case .request:     return "questionmark.bubble"
        case .reasoning:   return "brain"
        case .output:      return "curlybraces"
        case .prefill:     return "text.cursor"
        }
    }

    var supportsWrapper: Bool {
        switch self {
        case .background, .history, .request, .examples: return true
        default: return false
        }
    }

    var wrapperTag: String? {
        switch self {
        case .background: return "context"
        case .history:    return "history"
        case .request:    return "request"
        case .examples:   return "example"
        default:          return nil
        }
    }

    var placeholder: String {
        switch self {
        case .taskContext:
            return "You are a senior Swift engineer pair-programming with me on a macOS app. The codebase uses SwiftUI and SwiftData…"
        case .tone:
            return "Direct, concise, no fluff. Skip preamble. Match the existing code style."
        case .background:
            return "Paste relevant docs, file contents, error messages, or design specs here."
        case .rules:
            return "- Prefer editing existing files over creating new ones\n- Don't add comments unless the why is non-obvious\n- If unsure, ask before guessing"
        case .examples:
            return "User: How do I add a new view?\nAssistant: <walks through the existing pattern step by step>"
        case .history:
            return "Compact summary of prior turns, or paste the relevant excerpt."
        case .request:
            return "The thing you want done right now."
        case .reasoning:
            return "Reason carefully before answering. Do not reveal private reasoning. Return only the final answer."
        case .output:
            return "Return a unified diff inside ```diff fences. No prose outside the fence."
        case .prefill:
            return "<response>"
        }
    }
}

struct PromptBlock: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: PromptBlockKind
    var content: String
    var enabled: Bool
    var useWrapper: Bool

    init(kind: PromptBlockKind,
         content: String = "",
         enabled: Bool = true,
         useWrapper: Bool? = nil,
         id: UUID = UUID()) {
        self.id = id
        self.kind = kind
        self.content = content
        self.enabled = enabled
        self.useWrapper = useWrapper ?? kind.supportsWrapper
    }

    static func defaultBlocks() -> [PromptBlock] {
        PromptBlockKind.allCases.map { kind in
            PromptBlock(kind: kind, enabled: kind != .prefill)
        }
    }
}
