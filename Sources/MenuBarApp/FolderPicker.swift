import AppKit
import Foundation

/// The one place `NSOpenPanel` gets shown — onboarding and Settings' "Add
/// Folder…" both go through this. Presenting the panel is what grants sandbox
/// access to whatever the user picks; the caller still has to turn that into a
/// lasting bookmark via `SecurityScope.grant`.
enum FolderPicker {
    static let promptMessage =
        "Choose a Claude Code config folder — the one containing a \u{201c}projects\u{201d} folder."

    static func choose(message: String, suggesting url: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        // The folder we're after is a dot-directory; without this the user
        // can't see it to select it.
        panel.showsHiddenFiles = true
        panel.message = message
        panel.prompt = "Grant Access"
        panel.directoryURL = url

        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Every "Choose folder" button in this app should call this, and only
    /// this — not `addFolder(suggestedFolder)` directly. A security-scoped
    /// bookmark can only be created for a URL the user picked through an
    /// actual Open panel; skipping the panel and granting a hardcoded path
    /// silently fails under the sandbox, with no error to show for it.
    static func chooseAndGrant(_ grant: (URL) -> Void) {
        guard let url = choose(message: promptMessage, suggesting: suggestedFolder) else { return }
        grant(url)
    }

    static var defaultClaudeFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
    }

    /// `CLAUDE_CONFIG_DIR`, when Claude Code's config has been relocated.
    /// Reading the environment needs no sandbox permission — only opening the
    /// path it names does, which is exactly what the panel grants.
    static var suggestedFolder: URL {
        if let configured = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"],
           !configured.isEmpty {
            return URL(fileURLWithPath: (configured as NSString).expandingTildeInPath,
                       isDirectory: true)
        }
        return defaultClaudeFolder
    }
}
