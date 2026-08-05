import AppKit

/// Small OS-level actions onboarding and Settings both need. Kept to things
/// the sandbox allows with no extra entitlement: launching another app via
/// `NSWorkspace` (unlike spawning an arbitrary subprocess) and the clipboard.
enum SystemActions {
    static func openTerminal() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
    }

    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
