import SwiftUI

/// Shown in place of the ordinary popover before any folder has been granted.
/// The app is sandboxed, so this isn't an edge case — it's the very first
/// thing every install sees. Two real steps, in order: Claude Usage doesn't
/// authenticate anyone itself, it only reads what Claude Code already wrote
/// to disk after *you* sign in there.
struct OnboardingView: View {
    var grantedFolders: [URL] = []
    var grantFolder: () -> Void = {}

    private static let loginCommand = "claude login"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.questionmark")
                    .foregroundStyle(.secondary)
                Text("Get started")
                    .font(.system(size: 12, weight: .semibold))
            }

            step(1, "Sign in to Claude Code") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Claude Usage has no login of its own — it reads data Claude Code already stores on this Mac. If you haven't signed in there yet, install Claude Code and run:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text(Self.loginCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button("Copy") { SystemActions.copyToClipboard(Self.loginCommand) }
                            .buttonStyle(.borderless)
                            .font(.caption)
                    }
                    .padding(6)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    Button("Open Terminal", action: SystemActions.openTerminal)
                        .controlSize(.small)
                }
            }

            step(2, "Grant this app access") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("macOS keeps your Claude Code folder private until you pick it yourself. Nothing is sent anywhere except one request to Anthropic, using your own login.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        grantFolder()
                    } label: {
                        Text("Choose “.claude” Folder…")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if !grantedFolders.isEmpty {
                        Text("None of the folders you picked look like a Claude Code config folder yet — expected a “projects” subfolder inside. Make sure step 1 is done, then try again.")
                            .font(.system(size: 10))
                            .foregroundStyle(Level.warn.tint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider().padding(.vertical, 2)

            HStack {
                SettingsLink { Text("Settings…") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.link)
            .font(.system(size: 11))
        }
    }

    @ViewBuilder
    private func step<Content: View>(
        _ number: Int, _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(.secondary))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            content()
                .padding(.leading, 22)
        }
    }
}
