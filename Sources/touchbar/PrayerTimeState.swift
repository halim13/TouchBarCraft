import Foundation
import SwiftUI
import Observation

private let prayerApiBase = "https://islamicapi.com/api/v1/prayer-time/"

private func parsePrayerTime(_ timeStr: String) -> (hour: Int, minute: Int)? {
    let trimmed = timeStr.trimmingCharacters(in: .whitespaces)
    let formatter24 = DateFormatter()
    formatter24.dateFormat = "HH:mm"
    formatter24.locale = Locale(identifier: "en_US_POSIX")
    if let date = formatter24.date(from: trimmed) {
        let comp = Calendar.current.dateComponents([.hour, .minute], from: date)
        if let h = comp.hour, let m = comp.minute { return (h, m) }
    }
    let formatter12 = DateFormatter()
    formatter12.dateFormat = "h:mm a"
    formatter12.locale = Locale(identifier: "en_US_POSIX")
    if let date = formatter12.date(from: trimmed) {
        let comp = Calendar.current.dateComponents([.hour, .minute], from: date)
        if let h = comp.hour, let m = comp.minute { return (h, m) }
    }
    return nil
}

let PrayerNames: [String] = ["Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha"]

private func timeString(from date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    return f.string(from: date)
}

struct CachedPrayerData: Codable {
    let month: String
    let data: [String: [String: String]]
    let lastUpdated: Date
}

@Observable
@MainActor
public final class PrayerTimeState {
    public static var shared: PrayerTimeState?

    public var prayerTimes: [String: [String: String]] = [:]
    public var currentMonth: String = ""
    public var isLoading = false
    public var errorMessage = ""
    public var lastUpdated: Date?

    public private(set) var currentNextPrayerName: String = "—"
    public private(set) var currentTimeRemainingFormatted: String = ""

    private let cachePath: URL

    public init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        cachePath = home.appendingPathComponent(".touchbarcraft_prayer_cache.json")
        Self.shared = self
        loadCache()
        if let custom = customTimesConfig, custom.useCustom {
            refreshCurrentPrayer()
            startAutoRefresh()
        } else {
            if !prayerTimes.isEmpty {
                refreshCurrentPrayer()
                startAutoRefresh()
            }
            if currentMonth.isEmpty || !isCurrentMonthCached {
                Task { await fetchCurrentMonth() }
            }
        }
    }

    private func startAutoRefresh() {
        Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard let self else { break }
                await self.refreshCurrentPrayer()
            }
        }
    }

    @MainActor
    public func refreshCurrentPrayer() {
        let newName = nextPrayerName
        let newRemaining = timeRemainingFormatted
        if currentNextPrayerName != newName || currentTimeRemainingFormatted != newRemaining {
            currentNextPrayerName = newName
            currentTimeRemainingFormatted = newRemaining
        }
    }

    private var isCurrentMonthCached: Bool {
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        let month = fmt.string(from: now)
        return currentMonth == month && !prayerTimes.isEmpty
    }

    private var cacheFileExists: Bool {
        FileManager.default.fileExists(atPath: cachePath.path)
    }

    private func loadCache() {
        guard cacheFileExists else { return }
        do {
            let data = try Data(contentsOf: cachePath)
            let cached = try JSONDecoder().decode(CachedPrayerData.self, from: data)
            currentMonth = cached.month
            prayerTimes = cached.data
            lastUpdated = cached.lastUpdated
        } catch {
            print("PrayerTimeState: failed to load cache: \(error)")
        }
    }

    private func saveCache(month: String, data: [String: [String: String]]) {
        let cached = CachedPrayerData(month: month, data: data, lastUpdated: Date())
        do {
            let encoded = try JSONEncoder().encode(cached)
            try encoded.write(to: cachePath)
            currentMonth = month
            prayerTimes = data
            lastUpdated = cached.lastUpdated
        } catch {
            print("PrayerTimeState: failed to save cache: \(error)")
        }
    }

    public func fetchCurrentMonth() async {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        let month = fmt.string(from: Date())
        await fetchMonth(month)
    }

    public func fetchMonth(_ yearMonth: String) async {
        guard let state = AppState.shared else { return }
        guard let widget = state.widgets.first(where: { $0.type == .prayerTime }) else {
            errorMessage = "No prayer widget configured"
            return
        }
        let apiKey = widget.prayerApiKey
        let lat = widget.prayerLatitude
        let lon = widget.prayerLongitude

        guard !apiKey.isEmpty, !lat.isEmpty, !lon.isEmpty else {
            errorMessage = "Set API key, latitude & longitude first"
            return
        }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        let method = widget.prayerMethod
        let school = widget.prayerSchool

        guard var components = URLComponents(string: prayerApiBase) else { return }
        components.queryItems = [
            URLQueryItem(name: "lat", value: lat),
            URLQueryItem(name: "lon", value: lon),
            URLQueryItem(name: "date", value: yearMonth),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "method", value: String(method)),
            URLQueryItem(name: "school", value: String(school))
        ]

        guard let url = components.url else { return }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                errorMessage = "Server error"
                return
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let code = json?["code"] as? Int, code == 200,
                  let rawData = json?["data"] as? [[String: Any]] else {
                if let msg = json?["message"] as? String {
                    errorMessage = msg
                } else {
                    errorMessage = "Invalid response"
                }
                return
            }

            var result: [String: [String: String]] = [:]
            for day in rawData {
                guard let date = day["date"] as? String,
                      let times = day["times"] as? [String: String] else { continue }
                var filtered: [String: String] = [:]
                for name in PrayerNames {
                    if let t = times[name] {
                        filtered[name] = t
                    }
                }
                result[date] = filtered
            }

            saveCache(month: yearMonth, data: result)
            refreshCurrentPrayer()
            startAutoRefresh()
        } catch {
            if cacheFileExists {
                print("PrayerTimeState: fetch failed, using cache: \(error)")
            } else {
                errorMessage = "Failed to fetch: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Next Prayer Calculation

    private var customTimesConfig: (useCustom: Bool, times: [String: String])? {
        guard let state = AppState.shared,
              let widget = state.widgets.first(where: { $0.type == .prayerTime }),
              widget.prayerUseCustomTimes
        else { return nil }
        return (true, widget.prayerCustomTimes)
    }

    public var todayTimes: [String: String]? {
        if let custom = customTimesConfig, custom.useCustom {
            return custom.times.isEmpty ? nil : custom.times
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        return prayerTimes[today]
    }

    public var nextPrayerName: String {
        guard let times = todayTimes else { return "—" }
        let now = Date()
        let cal = Calendar.current
        let nowComp = cal.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (nowComp.hour ?? 0) * 60 + (nowComp.minute ?? 0)

        var next: (name: String, minutes: Int)?
        for name in PrayerNames {
            if name == "Sunrise" { continue }
            guard let t = times[name], let parsed = parsePrayerTime(t) else { continue }
            let prayerMinutes = parsed.hour * 60 + parsed.minute
            if prayerMinutes > nowMinutes {
                if next == nil || prayerMinutes < next!.minutes {
                    next = (name, prayerMinutes)
                }
            }
        }

        if let n = next {
            return n.name
        }
        return PrayerNames.first(where: { $0 != "Sunrise" }) ?? "Fajr"
    }

    public var nextPrayerTimeMinutes: Int? {
        guard let times = todayTimes else { return nil }
        let now = Date()
        let cal = Calendar.current
        let nowComp = cal.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (nowComp.hour ?? 0) * 60 + (nowComp.minute ?? 0)

        var next: (name: String, minutes: Int)?
        for name in PrayerNames {
            if name == "Sunrise" { continue }
            guard let t = times[name], let parsed = parsePrayerTime(t) else { continue }
            let prayerMinutes = parsed.hour * 60 + parsed.minute
            if prayerMinutes > nowMinutes {
                if next == nil || prayerMinutes < next!.minutes {
                    next = (name, prayerMinutes)
                }
            }
        }

        if let n = next {
            return n.minutes
        }

        if let firstPrayer = PrayerNames.first(where: { $0 != "Sunrise" }),
           let t = times[firstPrayer], let parsed = parsePrayerTime(t) {
            return parsed.hour * 60 + parsed.minute + 1440
        }
        return nil
    }

    public var timeRemainingSeconds: Int {
        guard let nextMinutes = nextPrayerTimeMinutes else { return 0 }
        let now = Date()
        let cal = Calendar.current
        let nowComp = cal.dateComponents([.hour, .minute], from: now)
        let nowMinutes = (nowComp.hour ?? 0) * 60 + (nowComp.minute ?? 0)

        if nextMinutes > nowMinutes {
            return (nextMinutes - nowMinutes) * 60
        }
        return (nextMinutes - nowMinutes + 1440) * 60
    }

    public var timeRemainingFormatted: String {
        let totalSeconds = timeRemainingSeconds
        if totalSeconds <= 0 { return "0m" }
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
