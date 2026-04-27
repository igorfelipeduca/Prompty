import Foundation

struct AIMessage: Identifiable, Equatable {
    enum Role: Equatable { case user, assistant }

    let id: UUID
    var role: Role
    var text: String
    var blocks: [PromptBlockKind: String]
    var isStreaming: Bool
    var previousBlocks: [PromptBlock]?
    var didApply: Bool

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        blocks: [PromptBlockKind: String] = [:],
        isStreaming: Bool = false,
        previousBlocks: [PromptBlock]? = nil,
        didApply: Bool = true
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.blocks = blocks
        self.isStreaming = isStreaming
        self.previousBlocks = previousBlocks
        self.didApply = didApply
    }
}
