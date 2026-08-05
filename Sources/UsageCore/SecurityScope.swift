import Foundation

/// Bookmarks to folders the user has explicitly granted access to.
///
/// The app is sandboxed, so `~/.claude` and any other Claude Code config
/// directory are invisible to it until the user picks them with an Open
/// panel. A security-scoped bookmark is what makes that grant survive a
/// relaunch — without one, every launch would ask again.
public enum SecurityScope {
    private static let defaultsKey = "grantedFolderBookmarks"
    private static let bookmarkOptions: URL.BookmarkCreationOptions = [
        .withSecurityScope, .securityScopeAllowOnlyReadAccess,
    ]

    /// Creates and stores a bookmark for a URL the caller obtained from an
    /// NSOpenPanel (or otherwise already has sandbox access to). Call
    /// `resolveAll()` afterwards to start accessing it.
    @discardableResult
    public static func grant(_ url: URL, defaults: UserDefaults = .standard) -> Bool {
        guard let data = try? url.bookmarkData(
            options: bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
        else { return false }
        var stored = storedBookmarks(defaults: defaults)
        stored.append(data)
        defaults.set(stored, forKey: defaultsKey)
        return true
    }

    /// Stops tracking a folder. Doesn't revoke access already granted this
    /// launch — there's no API to force that early — but it won't be resolved
    /// again on the next one.
    public static func revoke(_ url: URL, defaults: UserDefaults = .standard) {
        let target = url.standardizedFileURL.path
        let survivors = storedBookmarks(defaults: defaults).filter { data in
            var stale = false
            guard let resolved = try? URL(resolvingBookmarkData: data,
                                           options: [.withSecurityScope],
                                           relativeTo: nil, bookmarkDataIsStale: &stale)
            else { return true }
            return resolved.standardizedFileURL.path != target
        }
        defaults.set(survivors, forKey: defaultsKey)
    }

    /// Resolves and actively scopes every stored bookmark. Idempotent: safe to
    /// call again after `grant`/`revoke` to refresh the working set.
    ///
    /// Kept scoped for the process lifetime rather than started and stopped
    /// around each read — every profile is read on every 60s poll, so pairing
    /// start/stop per access buys nothing and only adds a chance to get the
    /// pairing wrong.
    @discardableResult
    public static func resolveAll(defaults: UserDefaults = .standard) -> [URL] {
        var resolved: [URL] = []
        var refreshed: [Data] = []
        for bookmark in storedBookmarks(defaults: defaults) {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark,
                                      options: [.withSecurityScope],
                                      relativeTo: nil, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource()
            else { continue }
            resolved.append(url)
            if stale, let fresh = try? url.bookmarkData(
                options: bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
                refreshed.append(fresh)
            } else {
                refreshed.append(bookmark)
            }
        }
        defaults.set(refreshed, forKey: defaultsKey)
        return resolved
    }

    private static func storedBookmarks(defaults: UserDefaults) -> [Data] {
        defaults.array(forKey: defaultsKey) as? [Data] ?? []
    }
}
