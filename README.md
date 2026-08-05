# Claude Usage

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Platform](https://img.shields.io/badge/macOS-14%2B-black.svg)
![Swift](https://img.shields.io/badge/built%20with-Swift%205.9-f05138.svg)

Claude Code usage in the macOS menu bar and as a desktop widget — session and
weekly limit percentages, token counts, and estimated cost.

## What it reads

Two sources, both already on your machine. Nothing is sent anywhere except a
single authenticated request to Anthropic, using the login Claude Code already
did for you.

| Source | Gives |
|---|---|
| `api.anthropic.com/api/oauth/usage` | 5-hour and 7-day limit utilization, and when each resets |
| `<config dir>/projects/**/*.jsonl` | today / this week / current session token counts and estimated cost |

## Sandboxed, on purpose

This app is built for the Mac App Store, which means it runs inside Apple's
App Sandbox. That has one real consequence worth knowing about up front:

- **File access is opt-in.** The sandbox makes `~/.claude` invisible until you
  grant it, so the first launch asks you to pick your Claude Code config
  folder (usually `~/.claude`) in an Open panel. Everything after that —
  token counts, cost, project history — works automatically from that folder.
- **The Keychain is opt-in too, differently.** Claude Code stores your login
  token in a Keychain item that belongs to *Claude Code*, not to this app —
  and the sandbox does not let one app read another's Keychain entry. If your
  profile also has a `.credentials.json` file inside its config folder
  (relocated profiles usually do), the session/weekly percentages work with no
  extra steps. If it doesn't — the ordinary case for a default, un-relocated
  install — open **Settings → Access Token** and paste it once:

  ```sh
  security find-generic-password -s "Claude Code-credentials" -w
  ```

  Settings has a "Copy Command" button for this. The pasted token is stored in
  this app's own Keychain item — never written to disk, never sent anywhere
  but Anthropic. It expires periodically; when it does, the app tells you and
  you repeat the one command. Token counts and cost never depend on this —
  those always come straight from the folder you granted.

## Profiles

A profile is a Claude Code config folder — one logged-in account. Add as many
as you like in Settings; each keeps its own cache, its own history file, and
(if you paste one) its own token, so one account can never show another's
numbers. Every widget picks its own profile independently, so you can place
one per account, or one per project, side by side.

## Architecture

```
Sources/
  UsageCore/     data layer, no UI — shared by the app, the widget, and the CLI
  SharedViews/   the ring gauge and palette, shared by the app and the widget
  MenuBarApp/    MenuBarExtra, the 60s poller, settings, onboarding
  Widget/        AppIntent configuration and the widget families
  UsageCLI/      prints the snapshot; a Terminal-only tool with full FS access
```

`swift test` covers `UsageCore` with no Xcode involved. The app and widget
bundle is built by Xcode via XcodeGen, since SPM can't express an app that
embeds an extension. Both build systems compile `Sources/UsageCore` directly —
there's no framework target to embed and sign.

**Both the app and the widget are sandboxed.** That's a real architectural
difference from an unsandboxed menu bar utility, and it's why:

- `SecurityScope.swift` manages security-scoped bookmarks to whatever folders
  you grant in Settings, so access survives a relaunch.
- `Credentials.swift` never shells out to `/usr/bin/security` (the sandbox
  forbids spawning arbitrary executables) — it reads `.credentials.json`
  inside a granted folder, or a token you pasted into this app's own Keychain
  item.
- The host app and the widget share data through a real **App Group**
  (`group.com.beyrami.claude-usage`), backed by an Apple Developer Program
  provisioning profile — the supported way for two sandboxed processes on the
  same Mac to exchange files. (An unsandboxed build has no such profile to
  lean on, which is why ad-hoc, non-App-Store forks of this idea sometimes
  resort to writing directly into the widget's container instead.)

## Try the data layer

Runs on any Mac with a Swift toolchain, no Xcode project needed. The CLI is a
plain Terminal process — not sandboxed — so unlike the app it looks for
`~/.claude` on its own:

```sh
swift run usage-cli              # human-readable summary
swift run usage-cli --profiles   # list discovered profiles
swift run usage-cli --json       # exactly what the widget will render
swift run usage-cli --write      # write the snapshot files to disk
```

## Building the app

Requires macOS 14+, full Xcode (not just the Command Line Tools), and
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
./build.sh
```

`project.yml` is pinned to a specific Team ID and bundle ID prefix — edit
`DEVELOPMENT_TEAM` and `options.bundleIdPrefix` if you're building this under
your own Apple Developer account instead.

## Cost accuracy

Costs are computed from token counts, because current Claude Code transcripts
no longer record a `costUSD` field. Cache writes are billed by TTL — 1.25x
input for the 5-minute cache and 2x for the 1-hour cache — and Claude Code
writes almost exclusively 1-hour entries. Collapsing both into the 5-minute
rate understates the real figure substantially.

On Pro/Max plans this is notional equivalent API spend, not money you were
charged. Rates live in `Sources/UsageCore/Pricing.swift`; edit them when
Anthropic changes pricing.

Scanning is incremental — per-file byte offsets, so a 60s poll re-reads only
what was appended rather than the gigabytes an active projects folder can
accumulate.

## History and projects

Daily totals are kept in the app's own Application Support directory. They
have to be recorded rather than recomputed: the scanner only reads the last 7
days of transcripts, and Claude Code prunes them after about a month. On first
launch a one-off backfill reads the whole archive so the chart starts
populated instead of filling in over a week.

Project names come from each entry's `cwd`. The directory name under a
profile's `projects` folder is a slug that flattens `/`, `\` and `_` all to
`-`, so it can't be reversed into a real name; `cwd` is exact.

## Privacy

Nothing about your usage, your code, or your machine is sent anywhere except
the one authenticated request to `api.anthropic.com`, made with your own
credentials, to fetch your own numbers. See [`docs/privacy.html`](docs/privacy.html)
for the App Store–facing privacy policy.

## Acknowledgements

The data model — reading Claude Code's OAuth usage endpoint and its
transcript logs, and the cache-TTL cost math in particular — is adapted from
the open-source [claude-usage-streamdeck-plugin](https://github.com/saeedkolivand/claude-usage-streamdeck-plugin)
and [claude-usage-mac](https://github.com/saeedkolivand/claude-usage-mac)
projects by Saeed Kolivand (MIT licensed). This is an independent,
from-scratch rebuild targeting the Mac App Store's sandboxing requirements,
with a different credential model, a different app/widget data-sharing
mechanism, and its own onboarding flow — but the core insight (where the
numbers live, and how to price them correctly) is theirs.

## License

MIT
