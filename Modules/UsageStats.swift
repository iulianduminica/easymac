import Foundation

/// Tracks lightweight usage metrics (in-memory + persisted counts).
final class UsageStats {
    static let shared = UsageStats()
    private init() {}

    private let defaults = UserDefaults.standard
    private let keyPrefix = "UsageStat_"
    private let allKey = "UsageStat_AllEvents"

    func increment(_ name: String, by value: Int = 1) {
        let key = keyPrefix + name
        let new = defaults.integer(forKey: key) + value
        defaults.set(new, forKey: key)
        let all = defaults.integer(forKey: allKey) + value
        defaults.set(all, forKey: allKey)
    }

    func value(_ name: String) -> Int { defaults.integer(forKey: keyPrefix + name) }
    func allEvents() -> Int { defaults.integer(forKey: allKey) }

    func snapshot() -> [String: Int] {
        var out: [String: Int] = ["_all": allEvents()]
        for (k, v) in defaults.dictionaryRepresentation() {
            guard k.hasPrefix(keyPrefix), let i = v as? Int else { continue }
            out[String(k.dropFirst(keyPrefix.count))] = i
        }
        return out
    }
    func exportJSON() -> Data? { try? JSONSerialization.data(withJSONObject: snapshot(), options: [.prettyPrinted]) }
    func importJSON(_ data: Data) throws {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        for (k,v) in obj where k != "_all" { if let i = v as? Int { defaults.set(i, forKey: keyPrefix + k) } }
        if let total = obj["_all"] as? Int { defaults.set(total, forKey: allKey) }
    }
}
