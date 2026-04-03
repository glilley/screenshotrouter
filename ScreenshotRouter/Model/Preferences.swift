import Foundation
import Carbon

class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Key: String {
        case folders = "destinationFolders"
        case hotKeyCode = "hotKeyCode"
        case hotKeyModifiers = "hotKeyModifiers"
    }

    // MARK: - Folders (stored as security-scoped bookmarks)

    var folders: [URL] {
        get {
            guard let bookmarks = defaults.array(forKey: Key.folders.rawValue) as? [Data] else {
                return []
            }
            return bookmarks.compactMap { resolveBookmark($0) }
        }
        set {
            let bookmarks = newValue.compactMap { createBookmark(for: $0) }
            defaults.set(bookmarks, forKey: Key.folders.rawValue)
        }
    }

    func addFolder(_ url: URL) {
        var current = folders
        guard !current.contains(url) else { return }
        current.append(url)
        folders = current
    }

    func removeFolder(at index: Int) {
        var current = folders
        guard index < current.count else { return }
        current.remove(at: index)
        folders = current
    }

    func moveFolder(from source: Int, to destination: Int) {
        var current = folders
        guard source < current.count, destination < current.count else { return }
        let item = current.remove(at: source)
        current.insert(item, at: destination)
        folders = current
    }

    // MARK: - Hot Key

    /// Default: Ctrl+Option+Cmd+4 (triple-modifier combo is very unlikely to conflict)
    var hotKeyCode: UInt32 {
        get {
            let stored = defaults.integer(forKey: Key.hotKeyCode.rawValue)
            return stored == 0 ? UInt32(kVK_ANSI_4) : UInt32(stored)
        }
        set { defaults.set(Int(newValue), forKey: Key.hotKeyCode.rawValue) }
    }

    /// Carbon modifier flags (cmdKey | controlKey | optionKey by default)
    var hotKeyModifiers: UInt32 {
        get {
            let stored = defaults.integer(forKey: Key.hotKeyModifiers.rawValue)
            return stored == 0 ? UInt32(cmdKey | controlKey | optionKey) : UInt32(stored)
        }
        set { defaults.set(Int(newValue), forKey: Key.hotKeyModifiers.rawValue) }
    }

    // MARK: - Bookmark helpers

    private func createBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale {
            // Refresh stale bookmark silently
            _ = createBookmark(for: url)
        }
        return url
    }
}
