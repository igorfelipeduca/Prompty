import Foundation
import SwiftData

@Model
final class PromptDocument {
    var name: String
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) private var blocksData: Data

    init(name: String = "Untitled Prompt", blocks: [PromptBlock] = PromptBlock.defaultBlocks()) {
        self.name = name
        self.createdAt = .now
        self.updatedAt = .now
        self.blocksData = (try? JSONEncoder().encode(blocks)) ?? Data()
    }

    var blocks: [PromptBlock] {
        get {
            (try? JSONDecoder().decode([PromptBlock].self, from: blocksData)) ?? PromptBlock.defaultBlocks()
        }
        set {
            blocksData = (try? JSONEncoder().encode(newValue)) ?? blocksData
            updatedAt = .now
        }
    }

    func updateBlock(id: UUID, transform: (inout PromptBlock) -> Void) {
        var current = blocks
        guard let idx = current.firstIndex(where: { $0.id == id }) else { return }
        transform(&current[idx])
        blocks = current
    }

    var assembledPrompt: String {
        PromptAssembler.assemble(blocks)
    }

    var characterCount: Int { assembledPrompt.count }
}
