//
//  GameTimerService.swift
//  Macpardy
//
//  Created by Jimmy Kane on 7/15/26.
//
import Foundation

@Observable
final class GameTimer {
    private var timer: Timer?

    /// Names the timer in log lines, e.g. "Question timer".
    @ObservationIgnored let name: String

    private(set) var remainingTime: TimeInterval
        private(set) var isRunning = false

        private(set) var startingTime: TimeInterval

    /// True while the time has run out. Changes only when the timer reaches
    /// zero or gets time back, so watching it doesn't redraw on every tick.
    private(set) var isExpired = false

    init(name: String = "Timer", seconds: TimeInterval = 15.0) {
            self.name = name
            self.startingTime = seconds
            self.remainingTime = seconds
        }

        func start() {
            guard !isRunning else { return }

            log("\(remainingTime < startingTime ? "resumed" : "started") at \(Self.format(remainingTime)) of \(Self.format(startingTime))")
            isRunning = true

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }

                remainingTime -= 0.1

                if remainingTime <= 0 {
                    remainingTime = 0
                    log("expired")
                    updateExpired()
                    // Let the warning's closing tone finish.
                    halt()
                } else {
                    updateWarning()
                }
            }
            updateWarning()
        }

        func stop() {
            if isRunning { log("paused at \(Self.format(remainingTime))") }
            halt()
            stopWarning()
        }

        private func halt() {
            timer?.invalidate()
            timer = nil
            isRunning = false
        }

        /// Stops the timer and returns it to its starting time. With `seconds`,
        /// that starting time changes too (the length set in Settings).
        func reset(seconds: TimeInterval? = nil) {
            stop()
            isWarningSpent = false
            if let seconds { startingTime = seconds }
            if remainingTime != startingTime {
                log("reset from \(Self.format(remainingTime)) to \(Self.format(startingTime))")
            }
            remainingTime = startingTime
            updateExpired()
        }

    /// Sets `isExpired` only when it actually changes, so observers aren't
    /// notified on every tick.
    private func updateExpired() {
        let expired = remainingTime <= 0
        if expired != isExpired { isExpired = expired }
    }

    func addSeconds(_ amount: Int) {
        let wasExpired = remainingTime <= 0
        let before = remainingTime
        remainingTime = max(0, remainingTime + TimeInterval(amount))
        log("\(amount >= 0 ? "+" : "")\(amount)s: \(Self.format(before)) → \(Self.format(remainingTime))")
        updateExpired()
        if wasExpired, remainingTime > 0 {
            // Time is back after running out: the warning starts over on the way down.
            stopWarning()
            isWarningSpent = false
        } else if isWarning {
            // Extra time during the warning cuts it short for this clue; it isn't replayed on the way back down.
            isWarningSpent = true
            stopWarning()
        }
    }

    // MARK: - Log (#87)

    /// Start, pause, resume, reset and expiry only; never each tick.
    private func log(_ event: String) {
        AppLogger.control.state("\(name) \(event)")
    }

    /// "12.3s".
    private static func format(_ seconds: TimeInterval) -> String {
        "\((max(0, seconds) * 10).rounded() / 10)s"
    }

    // MARK: - Warning sound

    /// The length of the `timerWarning` sound's ticks, which end when the time runs out.
    static let warningSeconds: TimeInterval = 5

    private var isWarning = false

    /// Set when added time cut the warning short. Cleared by `reset()`.
    private var isWarningSpent = false

    /// Starts the ticking once the last seconds begin, timed so it ends as the clock hits zero.
    /// Does nothing on timers shorter than the warning itself.
    private func updateWarning() {
        guard !isWarning, !isWarningSpent, isRunning, startingTime > Self.warningSeconds,
              remainingTime > 0, remainingTime <= Self.warningSeconds else { return }
        isWarning = true
        SoundPlayer.shared.play(.timerWarning, from: Self.warningSeconds - remainingTime)
    }

    private func stopWarning() {
        guard isWarning else { return }
        isWarning = false
        SoundPlayer.shared.stop(.timerWarning)
    }
}
