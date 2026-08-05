import SwiftUI

/// The app's actual front door. `LSUIElement` apps like this one have no Dock
/// icon and no window by default, so without this a first launch looks like
/// nothing happened — there's no confirmation the app is even running until
/// someone happens to notice a small status item appear in the menu bar.
/// This opens automatically until setup is done (see `ClaudeUsageApp`), and
/// stays reachable afterwards from the popover footer.
struct WelcomeView: View {
    var grantedFolders: [URL] = []
    var grantFolder: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            preview

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 20) {
                    SetupStep(number: 1, title: "Sign in to Claude Code") { SignInStep() }
                    SetupStep(number: 2, title: "Grant this app access") {
                        GrantAccessStep(grantedFolders: grantedFolders, grantFolder: grantFolder)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                menuBarPointer
            }

            Divider()
            howItWorks
        }
        .padding(28)
        .frame(width: 580)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Level.ok.tint)
                Text("Welcome to Claude Usage")
                    .font(.system(size: 20, weight: .bold))
            }
            Text("Session and weekly Claude Code limits, token counts, and estimated cost — always one click away. Two things to set up first, both one-time.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    /// Sample data, so "what you'll see" is concrete instead of a promise —
    /// the same `.preview` fixture the widget gallery and snapshot tests use,
    /// so this can't show something the real popover doesn't actually render.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT YOU'LL SEE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
            HStack(spacing: 24) {
                MetricGauge(snapshot: .preview, metric: .session, lineWidth: 8)
                    .frame(width: 84)
                MetricGauge(snapshot: .preview, metric: .weekly, lineWidth: 8)
                    .frame(width: 84)
                VStack(alignment: .leading, spacing: 6) {
                    StatRow(label: "Today", tokens: Snapshot.preview.stats.todayTokens,
                            cost: Snapshot.preview.stats.todayCost)
                    StatRow(label: "This week", tokens: Snapshot.preview.stats.weekTokens,
                            cost: Snapshot.preview.stats.weekCost)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    /// The single most common point of confusion for a menu-bar-only app:
    /// nothing else on screen tells you where to look.
    private var menuBarPointer: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Look up here")
                .font(.system(size: 11, weight: .semibold))
            Text("Claude Usage lives in your menu bar, top-right of the screen. Click the icon anytime — that's the whole app.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 150)
        .padding(14)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW IT WORKS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
            fact("Limit percentages come straight from Anthropic, using the login Claude Code already did — this app never signs you in itself.")
            fact("Token counts and cost are computed from transcripts already on this Mac, in the folder you grant in step 2.")
            fact("Nothing is sent anywhere except that one request to Anthropic. No analytics, no server of ours, nothing collected.")
        }
    }

    private func fact(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Level.ok.tint)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
