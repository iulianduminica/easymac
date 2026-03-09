import Foundation

/// Pure functions (no side effects) to aid in file operations & testability.
enum PureUtilities {
    /// Returns a non-conflicting filename by appending incremental suffix before extension.
    /// existing: set of names already present (case-insensitive).
    static func conflictFreeName(base: String, existing: Set<String>) -> String {
        let lowerExisting = Set(existing.map { $0.lowercased() })
        if !lowerExisting.contains(base.lowercased()) { return base }
        let url = URL(fileURLWithPath: base)
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 1
        while true {
            let candidate = stem + " " + String(counter) + (ext.isEmpty ? "" : "." + ext)
            if !lowerExisting.contains(candidate.lowercased()) { return candidate }
            counter += 1
        }
    }

    /// Filters out paths located inside hidden directories (starting with a dot) unless allowHidden is true.
    static func filterHidden(paths: [String], allowHidden: Bool) -> [String] {
        guard !allowHidden else { return paths }
        return paths.filter { componentVisible($0) }
    }

    private static func componentVisible(_ path: String) -> Bool {
        for c in path.split(separator: "/") where c.hasPrefix(".") && c.count > 1 { return false }
        return true
    }
}
