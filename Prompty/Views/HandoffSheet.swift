import SwiftUI
import AppKit

struct HandoffSheet: View {
    let blocks: [PromptBlock]
    let onClose: () -> Void

    @AppStorage("handoffWorkdir")  private var workdirPath: String = NSHomeDirectory()
    @AppStorage("handoffTerminal") private var terminalRawValue: String = TerminalChoice.terminal.rawValue

    @State private var installedTerminals: [TerminalChoice] = TerminalChoice.installed

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    workdirSection
                    terminalSection
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 520)
        .frame(minHeight: 460, idealHeight: 540)
        .onAppear {
            installedTerminals = TerminalChoice.installed
            if !installedTerminals.contains(where: { $0.rawValue == terminalRawValue }),
               let first = installedTerminals.first {
                terminalRawValue = first.rawValue
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("ClaudeMark")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 22, height: 22)
                .padding(8)
                .background(Color(red: 0.85, green: 0.45, blue: 0.27),
                            in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Hand off to Claude")
                    .font(.headline)
                Text("Open a Claude Code session with this prompt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(.background.secondary, in: Circle())
            }
            .buttonStyle(.plain)
            .clickable()
        }
        .padding(16)
    }

    private var workdirSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Working directory")

            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
                Text(displayWorkdir)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Browse…") {
                    chooseWorkdir()
                }
                .clickable()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.gray.opacity(0.18), lineWidth: 1)
            )

            Text("Claude will start in this directory. Pick the project root.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var terminalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Terminal")

            if installedTerminals.isEmpty {
                Text("No supported terminal found. Install Terminal.app or another terminal and reopen this sheet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(installedTerminals) { choice in
                        terminalCard(choice)
                    }
                }
            }
        }
    }

    private func terminalCard(_ choice: TerminalChoice) -> some View {
        let isSelected = choice.rawValue == terminalRawValue

        return Button {
            terminalRawValue = choice.rawValue
        } label: {
            HStack(spacing: 10) {
                if let icon = choice.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "terminal")
                        .frame(width: 22, height: 22)
                }
                Text(choice.displayName)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.18),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .clickable()
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel", action: onClose)
                .keyboardShortcut(.cancelAction)
                .clickable()

            Button {
                openHandoff()
            } label: {
                Label {
                    Text("Open in \(currentTerminal.displayName)")
                        .fontWeight(.medium)
                } icon: {
                    Image("ClaudeMark")
                        .renderingMode(.original)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                }
                .foregroundStyle(.white)
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.85, green: 0.45, blue: 0.27))
            .disabled(installedTerminals.isEmpty || PromptAssembler.assemble(blocks).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .clickable()
        }
        .padding(16)
    }

    private var currentTerminal: TerminalChoice {
        TerminalChoice(rawValue: terminalRawValue) ?? installedTerminals.first ?? .terminal
    }

    private var displayWorkdir: String {
        let home = NSHomeDirectory()
        if workdirPath.hasPrefix(home) {
            return "~" + workdirPath.dropFirst(home.count)
        }
        return workdirPath
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
    }

    private func chooseWorkdir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose the working directory for Claude Code"
        panel.title = "Working directory"

        let initial = URL(fileURLWithPath: workdirPath, isDirectory: true)
        if FileManager.default.fileExists(atPath: initial.path) {
            panel.directoryURL = initial
        } else {
            panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        }

        if panel.runModal() == .OK, let url = panel.url {
            workdirPath = url.path
        }
    }

    private func openHandoff() {
        let workdir = URL(fileURLWithPath: workdirPath, isDirectory: true)
        let prompt = PromptAssembler.assemble(blocks)
        ClaudeHandoff.open(prompt: prompt, workdir: workdir, terminal: currentTerminal)
        onClose()
    }
}
