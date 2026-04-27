# Prompty

A native macOS app for composing Claude Code prompts that won't drift. Built with SwiftUI, Liquid Glass, and on-device Apple Intelligence.

![Prompty hero](https://x.com/ducaswtf)

## What it does

Compose structured Claude Code prompts using the 10-block anatomy recommended by the Claude Code team:

1. **Task Context** — role, environment, goal
2. **Tone** — voice, style, brand
3. **Background** — source docs, retrieved chunks
4. **Rules** — constraints, do/don't, fallback
5. **Examples** — 1–3 strong examples
6. **Conversation History** — prior turns or summary
7. **Current Request** — the exact ask
8. **Reasoning** — reason carefully, privately
9. **Output Format** — JSON, tags, markdown
10. **Assistant Prefill** — optional opening

Each block is toggleable, has guidance, and auto-wraps in `<context>` / `<history>` / `<request>` / `<example>` tags where appropriate. Stable context first, volatile request late, output contract last.

## Features

- **10-block prompt anatomy** with live assembled preview
- **Apple Intelligence built in** — Build, Edit, Polish, Suggest with on-device foundation models. No API key, no usage limits, no data leaves your Mac.
- **Hand off to Claude** — spawn a Claude Code session in your terminal of choice (Terminal, iTerm, Warp, Ghostty, kitty, Alacritty, WezTerm) with your assembled prompt as the first message
- **Per-message undo** for any AI edit
- **Liquid Glass** UI, native macOS 26 feel

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon Mac (for Apple Intelligence)
- [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/setup) installed if you want terminal hand-off

## Install

Download the latest `.dmg` from the [Releases](../../releases) page, drag Prompty into Applications, and launch.

## Build from source

```bash
git clone https://github.com/<your-username>/Prompty.git
cd Prompty
open Prompty.xcodeproj
```

In Xcode, select the Prompty scheme and run. You'll need to set your own development team in Signing & Capabilities.

## Releases (for maintainers)

The release workflow builds, signs, notarizes, and publishes a DMG to GitHub Releases. To use it, configure these repository secrets in **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `CERTIFICATE_P12` | Base64-encoded `.p12` of your Developer ID Application certificate |
| `CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_ID_PASSWORD` | An app-specific password from [appleid.apple.com](https://appleid.apple.com/account/manage) |
| `APPLE_TEAM_ID` | Your 10-character Apple Team ID |

To export the certificate as base64 for `CERTIFICATE_P12`:

```bash
base64 -i Certificate.p12 -o Certificate.p12.base64
pbcopy < Certificate.p12.base64
```

Then trigger **Actions → Release Prompty → Run workflow** with a version (e.g. `1.0.0`).

## License

MIT — see [LICENSE](LICENSE).

## Credits

Built by [@ducaswtf](https://x.com/ducaswtf).
