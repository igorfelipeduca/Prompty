import Foundation

enum PromptTemplate: String, CaseIterable, Identifiable {
    case empty
    case full
    case minimal
    case codeReview
    case bugInvestigation

    var id: String { rawValue }

    var label: String {
        switch self {
        case .empty:            return "Empty"
        case .full:             return "Full Recommended Flow"
        case .minimal:          return "Minimal Prompt"
        case .codeReview:       return "Code Review"
        case .bugInvestigation: return "Bug Investigation"
        }
    }

    var subtitle: String {
        switch self {
        case .empty:            return "Start from scratch"
        case .full:             return "All 10 blocks pre-filled with the official template"
        case .minimal:          return "Role, tone, task, rules, output"
        case .codeReview:       return "Reviewing a diff or PR"
        case .bugInvestigation: return "Root-causing a bug before fixing"
        }
    }

    var defaultName: String {
        switch self {
        case .empty:            return "New Prompt"
        case .full:             return "Full Template Prompt"
        case .minimal:          return "Minimal Prompt"
        case .codeReview:       return "Code Review Prompt"
        case .bugInvestigation: return "Bug Investigation Prompt"
        }
    }

    func makeBlocks() -> [PromptBlock] {
        switch self {
        case .empty:
            return PromptBlock.defaultBlocks()

        case .full:
            return [
                .init(kind: .taskContext, content: "You are [ROLE]. Your job is to [GOAL]. You are helping [USER TYPE] in [ENVIRONMENT]."),
                .init(kind: .tone,        content: "Use this tone: [TONE / VOICE / BRAND]."),
                .init(kind: .background,  content: "{{BACKGROUND_DATA_OR_DOCUMENTS}}"),
                .init(kind: .rules,       content: "Rules:\n- [RULE 1]\n- [RULE 2]\n- [RULE 3]\n- If unsure, [FALLBACK BEHAVIOR]"),
                .init(kind: .examples,    content: "User: [INPUT]\nAssistant: [GOOD OUTPUT]"),
                .init(kind: .history,     content: "{{HISTORY}}"),
                .init(kind: .request,     content: "{{REQUEST}}"),
                .init(kind: .reasoning,   content: "Reason carefully before answering. Do not reveal private reasoning. Return only the final answer."),
                .init(kind: .output,      content: "<response>\n[FINAL ANSWER]\n</response>"),
                .init(kind: .prefill,     content: "", enabled: false),
            ]

        case .minimal:
            return PromptBlockKind.allCases.map { kind in
                switch kind {
                case .taskContext: return .init(kind: .taskContext, content: "You are [ROLE].")
                case .tone:        return .init(kind: .tone,        content: "Tone: [TONE].")
                case .request:     return .init(kind: .request,     content: "Task: [WHAT TO DO].")
                case .rules:       return .init(kind: .rules,       content: "Rules:\n- [RULE 1]\n- [RULE 2]")
                case .output:      return .init(kind: .output,      content: "Output: [FORMAT].")
                default:           return .init(kind: kind, enabled: false)
                }
            }

        case .codeReview:
            return [
                .init(kind: .taskContext, content: "You are a senior engineer reviewing a pull request. Goal: catch real bugs and design issues, not nits."),
                .init(kind: .tone,        content: "Direct, technical, no flattery. One line per issue. Skip preamble."),
                .init(kind: .background,  content: "Paste the diff or PR description here."),
                .init(kind: .rules,       content: "- Only flag issues with concrete reproduction or user impact\n- Skip style nitpicks unless they hide bugs\n- Ignore changes not in the diff\n- If a change is correct, say so briefly"),
                .init(kind: .examples,    enabled: false),
                .init(kind: .history,     enabled: false),
                .init(kind: .request,     content: "Review the diff and list the highest-priority issues."),
                .init(kind: .reasoning,   content: "Walk through each hunk before answering. Do not show that walk-through."),
                .init(kind: .output,      content: "Markdown list. Each item: file:line — issue — suggested fix."),
                .init(kind: .prefill,     enabled: false),
            ]

        case .bugInvestigation:
            return [
                .init(kind: .taskContext, content: "You are debugging a reported bug. Goal: find the root cause before suggesting any fix."),
                .init(kind: .tone,        content: "Hypothesis-driven, evidence-first. State assumptions explicitly."),
                .init(kind: .background,  content: "Bug report:\n\nReproduction steps:\n\nLogs / stack trace:\n\nRelevant files:"),
                .init(kind: .rules,       content: "- Do not propose a fix until the root cause is identified\n- If evidence is missing, list what to gather next\n- Never assume the user is wrong about what they observed"),
                .init(kind: .examples,    enabled: false),
                .init(kind: .history,     enabled: false),
                .init(kind: .request,     content: "Investigate this bug. What is the root cause?"),
                .init(kind: .reasoning,   content: "Reason through the evidence step by step before answering."),
                .init(kind: .output,      content: "## Root cause\n…\n\n## Evidence\n…\n\n## Proposed fix\n…"),
                .init(kind: .prefill,     enabled: false),
            ]
        }
    }
}
