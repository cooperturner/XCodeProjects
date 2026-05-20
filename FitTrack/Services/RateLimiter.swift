import Foundation

/// Client-side rate limiter for outbound Claude API calls.
///
/// Two limits apply simultaneously:
///   - A minimum inter-call interval to prevent burst tapping.
///   - A rolling per-hour cap to protect the user's API key from runaway usage.
///
/// Both limits are in-memory only and reset when the app is restarted.
/// They are not a substitute for server-side rate limiting, but provide
/// a first line of defence against accidental over-consumption.
actor RateLimiter {
    static let shared = RateLimiter()
    private init() {}

    // Minimum seconds that must elapse between consecutive calls.
    private let minIntervalSeconds: TimeInterval = 3

    // Maximum calls permitted in any rolling 60-minute window.
    private let maxCallsPerHour = 20

    private var lastCallDate: Date?
    private var windowTimestamps: [Date] = []

    enum RateLimitError: Error, LocalizedError {
        case tooSoon(retryAfterSeconds: Int)
        case hourlyLimitReached

        var errorDescription: String? {
            switch self {
            case .tooSoon(let s):
                return "Please wait \(s) second\(s == 1 ? "" : "s") before making another AI request."
            case .hourlyLimitReached:
                return "Hourly AI request limit reached (20/hr). Please try again later."
            }
        }
    }

    /// Checks whether a new API call is permitted and records it if so.
    /// Throws `RateLimitError` if either limit would be exceeded.
    func checkAndRecord() throws {
        let now = Date()

        // Enforce minimum inter-call interval.
        if let last = lastCallDate {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < minIntervalSeconds {
                let retryAfter = Int(minIntervalSeconds - elapsed) + 1
                throw RateLimitError.tooSoon(retryAfterSeconds: retryAfter)
            }
        }

        // Prune timestamps outside the rolling 1-hour window.
        windowTimestamps = windowTimestamps.filter { now.timeIntervalSince($0) < 3600 }

        // Enforce hourly cap.
        guard windowTimestamps.count < maxCallsPerHour else {
            throw RateLimitError.hourlyLimitReached
        }

        lastCallDate = now
        windowTimestamps.append(now)
    }
}
