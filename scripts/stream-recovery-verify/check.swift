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
        print("PASS stream recovery, bounded output watchdog and private automation status")
    }
}
