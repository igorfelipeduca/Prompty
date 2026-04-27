import SwiftUI
import SwiftData

@main
struct PromptyApp: App {
    @AppStorage("aiButtonHidden") private var aiButtonHidden: Bool = false

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentSize)
        .modelContainer(for: PromptDocument.self)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandGroup(after: .toolbar) {
                Button(aiButtonHidden ? "Show AI Button" : "Hide AI Button") {
                    aiButtonHidden.toggle()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
    }
}
