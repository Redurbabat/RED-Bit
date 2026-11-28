import Foundation

@main struct VerifyStreamRecovery {
    static func main() {
        precondition(PlaybackRecoveryPolicy.canRecover(entrySource: "https://library.test/song", loadedSource: "https://library.test/song", origin: "local"))
        precondition(!PlaybackRecoveryPolicy.canRecover(entrySource: "/local/song.flac", loadedSource: "/local/song.flac", origin: "local"))
        precondition(!PlaybackRecoveryPolicy.canRecover(entrySource: "yt:track", loadedSource: "/downloads/saved.flac", origin: "local"))
        precondition(PlaybackRecoveryPolicy.canRecover(entrySource: "yt:track", loadedSource: "/cache/growing", origin: "cache"))
        var policy = PlaybackRecoveryPolicy()
        policy.select("one", resetAttempts: true)
        precondition(!policy.observe(position: 10, now: 0, playing: true, bufferedFrames: 0))
        precondition(!policy.observe(position: 10, now: 11.9, playing: true, bufferedFrames: 0))
        precondition(policy.observe(position: 10, now: 12, playing: true, bufferedFrames: 0))
        precondition(!policy.observe(position: 10, now: 13, playing: false, bufferedFrames: 0))
        precondition(!policy.observe(position: 10, now: 100, playing: true, bufferedFrames: 0))
        precondition(!policy.observe(position: 10, now: 120, playing: true, bufferedFrames: 2048))
        precondition(!policy.observe(position: 2, now: 121, playing: true, bufferedFrames: 0)) // Seek.
        precondition(!policy.observe(position: 2.5, now: 122, playing: true, bufferedFrames: 0)) // Progress.
        precondition(policy.claimRetry(position: 2.5, duration: 200))
        policy.select("one", resetAttempts: false)
        precondition(policy.claimRetry(position: 2.5, duration: 200))
        policy.select("one", resetAttempts: false)
        precondition(!policy.claimRetry(position: 2.5, duration: 200))
        policy.select("two", resetAttempts: false)
        precondition(!policy.claimRetry(position: 198, duration: 200)) // Natural end.
        precondition(policy.claimRetry(position: 2.5, duration: 200))
        policy.select("two", resetAttempts: true) // Explicit replay owns a new budget.
        precondition(policy.claimRetry(position: 2.5, duration: 200))
        var buffered = PlaybackRecoveryPolicy()
        buffered.select("buffered", resetAttempts: true)
        precondition(!buffered.observe(position: 10, now: 0, playing: true, bufferedFrames: 0))
        precondition(!buffered.observe(position: 10, now: 20, playing: true, bufferedFrames: 100))
        precondition(!buffered.observe(position: 10, now: 21, playing: true, bufferedFrames: 0))
        precondition(buffered.observe(position: 10, now: 32, playing: true, bufferedFrames: 0))
        var recovery = PlaybackRecoveryPolicy()
        recovery.select("failed", resetAttempts: true)
        precondition(!recovery.claimRetry(position: 198, duration: 200))
        precondition(recovery.claimRetry(position: 198, duration: 200, confirmedFailure: true))
        recovery.select("failed", resetAttempts: false)
        precondition(recovery.claimRetry(position: 198, duration: 0, confirmedFailure: true))
        recovery.select("failed", resetAttempts: false)
        precondition(!recovery.claimRetry(position: 198, duration: 0, confirmedFailure: true))
        var output = PlaybackOutputWatchdog()
        precondition(!output.observe(selection: 1, position: 4, now: 0, playing: true, bufferedFrames: 1024))
        precondition(!output.observe(selection: 1, position: 4, now: 11.9, playing: true, bufferedFrames: 1024))
        precondition(output.observe(selection: 1, position: 4, now: 12, playing: true, bufferedFrames: 1024))
        precondition(!output.observe(selection: 1, position: 4, now: 60, playing: true, bufferedFrames: 1024))
        precondition(!output.observe(selection: 2, position: 4, now: 60, playing: true, bufferedFrames: 1024))
        precondition(!output.observe(selection: 2, position: 4, now: 80, playing: false, bufferedFrames: 1024))
        precondition(!output.observe(selection: 2, position: 4, now: 90, playing: true, bufferedFrames: 1024))
        precondition(!output.observe(selection: 2, position: 4, now: 105, playing: true, bufferedFrames: 0))
        precondition(!output.observe(selection: 2, position: 4, now: 110, playing: true, bufferedFrames: 1024))
        precondition(!output.observe(selection: 2, position: 5, now: 121, playing: true, bufferedFrames: 1024))
        precondition(output.observe(selection: 2, position: 5, now: 133, playing: true, bufferedFrames: 1024))
        let status = RedBitAutomationStatus(state: .playing, hasTrack: true, position: 125.9,
            duration: 120.9, canNext: true, canPrevious: true, controlsLocked: false, hasPlaybackError: false)
        let statusData = Data(try! status.json().utf8)
        let object = try! JSONSerialization.jsonObject(with: statusData) as! [String: Any]
        precondition(Set(object.keys) == Set(["version", "state", "hasTrack", "positionSeconds",
            "durationSeconds", "canNext", "canPrevious", "controlsLocked", "hasPlaybackError"]))
        precondition(object["version"] as? Int == 1 && object["state"] as? String == "playing")
        precondition(status.positionSeconds == 120 && status.durationSeconds == 120)
        let locked = RedBitAutomationStatus(state: .buffering, hasTrack: true, position: .nan,
            duration: .infinity, canNext: true, canPrevious: true, controlsLocked: true, hasPlaybackError: true)
        precondition(!locked.canNext && !locked.canPrevious && locked.controlsLocked)
        precondition(locked.positionSeconds == nil && locked.durationSeconds == nil)
        precondition((try? locked.json()) != nil)
        let empty = RedBitAutomationStatus(state: .playing, hasTrack: false, position: 99,
            duration: 100, canNext: false, canPrevious: false, controlsLocked: false, hasPlaybackError: false)
        precondition(empty.state == .stopped && empty.positionSeconds == nil && empty.durationSeconds == nil)
        func snapshot(_ state: RedBitAutomationStatus.State, locked: Bool = false,
                      track: Bool = true, next: Bool = true, previous: Bool = true) -> RedBitAutomationStatus {
            RedBitAutomationStatus(state: state, hasTrack: track, position: 1, duration: 100,
                canNext: next, canPrevious: previous, controlsLocked: locked, hasPlaybackError: false)
        }
        for active in [RedBitAutomationStatus.State.playing, .buffering] {
            precondition(RedBitTransportCommand.play.decision(for: snapshot(active)) == .unchanged)
            precondition(RedBitTransportCommand.pause.decision(for: snapshot(active)) == .requested)
        }
        for idle in [RedBitAutomationStatus.State.paused, .stopped] {
            precondition(RedBitTransportCommand.play.decision(for: snapshot(idle)) == .requested)
            precondition(RedBitTransportCommand.pause.decision(for: snapshot(idle)) == .unchanged)
        }
        for command in [RedBitTransportCommand.play, .pause, .next, .previous] {
            precondition(command.decision(for: snapshot(.playing, locked: true)) == .locked)
            precondition(command.decision(for: snapshot(.stopped, track: false)) == .unavailable)
        }
        precondition(RedBitTransportCommand.next.decision(for: snapshot(.playing, next: false)) == .unavailable)
        precondition(RedBitTransportCommand.previous.decision(for: snapshot(.playing, previous: false)) == .unavailable)
        precondition(RedBitTransportCommand.next.decision(for: snapshot(.playing)) == .requested)
        precondition(RedBitTransportCommand.previous.decision(for: snapshot(.playing)) == .requested)
        let receipt = RedBitTransportCommand.Receipt(command: .pause, decision: .requested, status: snapshot(.paused))
        let receiptObject = try! JSONSerialization.jsonObject(with: Data(try! receipt.json().utf8)) as! [String: Any]
        precondition(Set(receiptObject.keys) == Set(["version", "command", "decision", "status"]))
        precondition(receiptObject["decision"] as? String == "requested")
        func adjust(_ command: RedBitAdjustment, state: RedBitAutomationStatus.State = .playing,
                    locked: Bool = false, loaded: Bool = true, mixing: Bool = false,
                    duration: Double = 100, enabled: Bool = false) -> RedBitAdjustment.Decision {
            command.decision(status: snapshot(state, locked: locked), volume: 0.5,
                             duration: duration, loaded: loaded, mixing: mixing, automixEnabled: enabled)
        }
        for value in [-1.0, 100.1, Double.nan, Double.infinity] {
            precondition(adjust(.volumePercent(value)) == .invalidValue)
        }
        precondition(adjust(.volumePercent(0)) == .requested)
        precondition(adjust(.volumePercent(100)) == .requested)
        precondition(adjust(.volumePercent(50)) == .unchanged)
        precondition(adjust(.seekSeconds(0)) == .requested)
        precondition(adjust(.seekSeconds(100)) == .requested)
        precondition(adjust(.seekSeconds(101)) == .invalidValue)
        precondition(adjust(.seekSeconds(-1)) == .invalidValue)
        precondition(adjust(.seekSeconds(.nan)) == .invalidValue)
        precondition(adjust(.seekSeconds(1), duration: .infinity) == .unavailable)
        precondition(adjust(.seekSeconds(1), duration: 0) == .unavailable)
        precondition(adjust(.seekSeconds(1), loaded: false) == .unavailable)
        precondition(adjust(.seekSeconds(1), state: .buffering) == .unavailable)
        precondition(adjust(.seekSeconds(1), state: .paused) == .requested)
        precondition(adjust(.seekSeconds(1), mixing: true) == .unavailable)
        precondition(adjust(.automix(true)) == .requested)
        precondition(adjust(.automix(false)) == .unchanged)
        precondition(adjust(.automix(true), mixing: true) == .unavailable)
        for command in [RedBitAdjustment.volumePercent(25), .seekSeconds(5), .automix(true)] {
            precondition(adjust(command, locked: true) == .locked)
        }
        let invalidReceipt = RedBitAdjustment.Receipt(adjustment: .volumePercent(.nan),
            decision: .invalidValue, status: snapshot(.playing), volume: .infinity, automixEnabled: false)
        let invalidObject = try! JSONSerialization.jsonObject(with: Data(try! invalidReceipt.json().utf8)) as! [String: Any]
        precondition(Set(invalidObject.keys) == Set(["version", "command", "decision", "status"]))
        let validReceipt = RedBitAdjustment.Receipt(adjustment: .volumePercent(50),
            decision: .unchanged, status: snapshot(.playing), volume: 0.5, automixEnabled: false)
        precondition(validReceipt.volumePercent == 50 && validReceipt.automixEnabled == nil)
        func preference(_ value: RedBitAutomationPreference, locked: Bool = false, mixing: Bool = false) -> RedBitAutomationPreference.Decision {
            value.decision(locked: locked, mixing: mixing, equalizer: false,
                wifiQuality: "HIGH", cellularQuality: "LOW", shuffle: false)
        }
        precondition(preference(.equalizer(true)) == .requested)
        precondition(preference(.equalizer(false)) == .unchanged)
        precondition(preference(.equalizer(true), locked: true) == .locked)
        precondition(preference(.streamQuality("HIGH", metered: false)) == .unchanged)
        precondition(preference(.streamQuality("HIGH", metered: true)) == .requested)
        precondition(preference(.streamQuality("LOW", metered: true)) == .unchanged)
        precondition(preference(.streamQuality("FLAC", metered: false)) == .invalidValue)
        precondition(preference(.streamQuality("LOW", metered: false), locked: true) == .locked)
        precondition(preference(.shuffle(true)) == .requested)
        precondition(preference(.shuffle(false)) == .unchanged)
        precondition(preference(.shuffle(true), mixing: true) == .unavailable)
        precondition(preference(.shuffle(true), locked: true) == .locked)
        for quality in RedBitAutomationPreference.Quality.allCases {
            precondition(preference(.streamQuality(quality.rawValue, metered: false)) != .invalidValue)
        }
        let queueSummary = RedBitQueueSummary(total: 8, upcoming: 5, automaticUpcoming: 3,
            shuffleEnabled: false, controlsLocked: true)
        precondition(queueSummary.manualUpcoming == 2)
        let queueJSON = try! JSONSerialization.jsonObject(with: Data(try! queueSummary.json().utf8)) as! [String: Any]
        precondition(Set(queueJSON.keys) == Set(["version", "total", "upcoming", "automaticUpcoming",
            "manualUpcoming", "shuffleEnabled", "controlsLocked"]))
        let invalidQueue = RedBitQueueSummary(total: -1, upcoming: 20, automaticUpcoming: 50,
            shuffleEnabled: true, controlsLocked: false)
        precondition(invalidQueue.total == 0 && invalidQueue.upcoming == 0 && invalidQueue.manualUpcoming == 0)
        let qualityReceipt = RedBitAutomationPreference.Receipt(preference: .streamQuality("bad", metered: true),
            decision: .invalidValue, equalizer: false, wifiQuality: "HIGH", cellularQuality: "LOW", shuffle: false)
        precondition(qualityReceipt.requestedQuality == "LOW" && qualityReceipt.metered == true)
        print("PASS stream recovery, output watchdog, private automation and audio/queue preferences")
    }
}
