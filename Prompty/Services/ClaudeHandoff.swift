import Foundation
import AppKit
import Darwin
import ApplicationServices

enum ClaudeHandoff {
    static func open(prompt: String, workdir: URL, terminal: TerminalChoice) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Pass the full formatted prompt (every assembled block) as Claude's first user
        // message. We write to a temp file and `cat` it so multi-line content + special
        // chars don't need bash escaping.
        let claudeCommand = buildClaudeCLICommand(prompt: prompt)
        PasteboardHelper.copy(claudeCommand.clipboardForm)

        switch terminal {
        case .terminal, .iterm, .hyper:
            launchViaCommandFile(workdir: workdir, terminal: terminal, command: claudeCommand)
        case .warp, .ghostty, .alacritty, .kitty, .wezterm:
            launchViaPaste(workdir: workdir, terminal: terminal, command: claudeCommand)
        }
    }

    // MARK: - Command construction

    private struct ClaudeCommand {
        let scriptBody: String          // bash invocation used in .command files
        let clipboardForm: String       // bash invocation for the paste flow
    }

    private static func buildClaudeCLICommand(prompt: String) -> ClaudeCommand {
        guard let scriptsDir = ensureScriptsDirectory() else {
            return ClaudeCommand(scriptBody: "claude", clipboardForm: "claude")
        }

        let stamp = "\(Int(Date().timeIntervalSince1970))-\(Int.random(in: 1000...9999))"
        let promptFile = scriptsDir.appendingPathComponent("prompty-prompt-\(stamp).txt")
        try? prompt.write(to: promptFile, atomically: true, encoding: .utf8)
        stripQuarantine(promptFile)

        let escapedPath = promptFile.path.replacingOccurrences(of: "'", with: "'\\''")
        let body = "claude \"$(cat '\(escapedPath)')\""
        return ClaudeCommand(scriptBody: body, clipboardForm: body)
    }

    // MARK: - .command file path (Terminal / iTerm / Hyper)

    private static func launchViaCommandFile(workdir: URL, terminal: TerminalChoice, command: ClaudeCommand) {
        guard let scriptsDir = ensureScriptsDirectory() else {
            openClaudeFallback()
            return
        }

        let stamp = "\(Int(Date().timeIntervalSince1970))-\(Int.random(in: 1000...9999))"
        let commandFile = scriptsDir.appendingPathComponent("prompty-launch-\(stamp).command")

        let escapedWorkdir = workdir.path.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        #!/bin/bash
        export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
        clear
        cd '\(escapedWorkdir)' || { echo "Working directory not accessible: \(escapedWorkdir)"; read -n 1 -s -r -p "Press any key…"; exit 1; }
        if ! command -v claude >/dev/null 2>&1; then
            echo "Claude Code CLI not found in PATH."
            echo "Install: https://docs.claude.com/en/docs/claude-code/setup"
            echo
            read -n 1 -s -r -p "Press any key to close…"
            exit 1
        fi
        exec \(command.scriptBody)
        """

        do {
            try script.write(to: commandFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: 0o755)],
                ofItemAtPath: commandFile.path
            )
            stripQuarantine(commandFile)

            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            if let appURL = terminal.appURL {
                NSWorkspace.shared.open([commandFile], withApplicationAt: appURL, configuration: config) { _, _ in }
            } else {
                NSWorkspace.shared.open(commandFile)
            }
        } catch {
            openClaudeFallback()
        }
    }

    // MARK: - Open + paste path (Warp / Ghostty / Alacritty / kitty / WezTerm)

    private static func launchViaPaste(workdir: URL, terminal: TerminalChoice, command: ClaudeCommand) {
        guard let appURL = terminal.appURL else {
            openClaudeFallback()
            return
        }

        let alreadyRunning = isAppRunning(bundleID: terminal.bundleID)
        let isTrusted = ensureAccessibility()

        let openTask = Process()
        openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openTask.arguments = ["-a", appURL.path, workdir.path]
        do {
            try openTask.run()
        } catch {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }

        guard isTrusted else {
            showClipboardHint(terminalName: terminal.displayName, missingAccessibility: true)
            return
        }

        let appName = appURL.deletingPathExtension().lastPathComponent
        let coldStartTimeout: TimeInterval = alreadyRunning ? 1.5 : 4.0
        waitForFrontmost(bundleID: terminal.bundleID, timeout: coldStartTimeout) { reached in
            let settle: TimeInterval = reached ? 0.6 : 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + settle) {
                sendPasteReturn(toApp: appName, terminalDisplayName: terminal.displayName)
            }
        }
    }

    private static func isAppRunning(bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    private static func waitForFrontmost(
        bundleID: String,
        timeout: TimeInterval,
        completion: @escaping (Bool) -> Void
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        func tick() {
            let frontBundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if frontBundle == bundleID {
                completion(true)
                return
            }
            if Date() >= deadline {
                completion(false)
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { tick() }
        }
        tick()
    }

    @discardableResult
    private static func ensureAccessibility() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private static func sendPasteReturn(toApp appName: String, terminalDisplayName: String) {
        let escapedAppName = appName.replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "\(escapedAppName)" to activate
        delay 0.4
        tell application "System Events"
            keystroke "v" using command down
            delay 0.2
            keystroke return
        end tell
        """
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error {
                showClipboardHint(
                    terminalName: terminalDisplayName,
                    error: error[NSAppleScript.errorMessage] as? String
                )
            }
        }
    }

    // MARK: - Helpers

    private static func ensureScriptsDirectory() -> URL? {
        guard let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let dir = support.appendingPathComponent("Prompty/Handoff", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func stripQuarantine(_ url: URL) {
        url.path.withCString { cPath in
            _ = removexattr(cPath, "com.apple.quarantine", 0)
        }
    }

    private static func openClaudeFallback() {
        let bundleIDs = ["com.anthropic.claudefordesktop", "com.anthropic.claude"]
        for id in bundleIDs {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }
        if let url = URL(string: "https://claude.ai/new") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func showClipboardHint(terminalName: String, missingAccessibility: Bool = false, error: String? = nil) {
        let isAutomationDenied = error?.contains("Not authorized") == true
            || error?.contains("System Events") == true

        let alert = NSAlert()
        alert.messageText = "Paste in \(terminalName) to start the session"

        if missingAccessibility || isAutomationDenied {
            let pane = isAutomationDenied ? "Automation" : "Accessibility"
            alert.informativeText = """
            Prompty needs \(pane) permission to auto-run the command in \(terminalName).
            Open System Settings → Privacy & Security → \(pane), enable Prompty for \
            “System Events”, and click “Hand off to Claude” again.

            The command is on your clipboard — press ⌘V then ↩︎ in \(terminalName) to start now.
            """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "OK")
        } else {
            alert.informativeText = """
            The command is on your clipboard.
            Press ⌘V then ↩︎ in \(terminalName) to start the Claude session.
            \(error.map { "\n(AppleScript error: \($0))" } ?? "")
            """
            alert.addButton(withTitle: "OK")
        }

        let response = alert.runModal()
        if (missingAccessibility || isAutomationDenied), response == .alertFirstButtonReturn {
            let urlString = isAutomationDenied
                ? "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
                : "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
