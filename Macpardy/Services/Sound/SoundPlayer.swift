//
//  SoundPlayer.swift
//  Macpardy
//

import AVFoundation
import Foundation
import Observation
import OSLog

/// Plays the game's sound effects and background music through the host's Mac.
///
/// Effects and music have separate on/off switches, remembered between launches.
/// A missing or unreadable sound file is logged and skipped; it never stops the game.
@Observable
final class SoundPlayer {

    static let shared = SoundPlayer()

    private enum Key {
        static let effects = "sound.effectsEnabled"
        static let music = "sound.musicEnabled"
    }

    var effectsEnabled: Bool {
        didSet {
            AppLogger.control.change("SoundPlayer.effectsEnabled", from: oldValue, to: effectsEnabled)
            defaults.set(effectsEnabled, forKey: Key.effects)
            if !effectsEnabled { stopEffects() }
        }
    }

    var musicEnabled: Bool {
        didSet {
            AppLogger.control.change("SoundPlayer.musicEnabled", from: oldValue, to: musicEnabled)
            defaults.set(musicEnabled, forKey: Key.music)
            syncMusic()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let bundle: Bundle
    @ObservationIgnored private var players: [SoundEffect: AVAudioPlayer] = [:]
    @ObservationIgnored private var wantsMusic = false

    init(defaults: UserDefaults = .standard, bundle: Bundle = .main) {
        self.defaults = defaults
        self.bundle = bundle
        self.effectsEnabled = defaults.object(forKey: Key.effects) as? Bool ?? true
        self.musicEnabled = defaults.object(forKey: Key.music) as? Bool ?? true
    }

    /// Plays an effect, if effects are on, starting `offset` seconds in.
    func play(_ effect: SoundEffect, from offset: TimeInterval = 0) {
        guard !effect.isMusic, effectsEnabled, let player = player(for: effect) else { return }
        player.currentTime = min(max(0, offset), player.duration)
        player.play()
        AppLogger.control.state("Sound played: \(effect.rawValue)\(offset > 0 ? " from \(offset)s" : "")")
    }

    func stop(_ effect: SoundEffect) {
        guard let player = players[effect] else { return }
        if player.isPlaying { AppLogger.control.state("Sound stopped: \(effect.rawValue)") }
        player.stop()
    }

    /// Reacts to the game entering `phase`: the music follows the board, and a
    /// running timer warning never carries over into the next phase.
    func handle(phase: GamePhase) {
        let cue = SoundCue.entering(phase)
        stop(.timerWarning)
        wantsMusic = cue.playsMusic
        syncMusic()
        if let effect = cue.effect { play(effect) }
    }

    func stopAll() {
        AppLogger.control.state("All sounds stopped")
        wantsMusic = false
        for player in players.values { player.stop() }
    }

    // MARK: - Private

    private func syncMusic() {
        if wantsMusic, musicEnabled {
            guard let player = player(for: .backgroundMusic), !player.isPlaying else { return }
            player.numberOfLoops = -1
            player.play()
            AppLogger.control.state("Sound played: \(SoundEffect.backgroundMusic.rawValue) (looping)")
        } else {
            stop(.backgroundMusic)
        }
    }

    private func stopEffects() {
        for (effect, player) in players where !effect.isMusic { player.stop() }
    }

    private func player(for effect: SoundEffect) -> AVAudioPlayer? {
        if let existing = players[effect] { return existing }
        guard let url = bundle.url(forResource: effect.rawValue, withExtension: effect.fileExtension) else {
            AppLogger.control.error("Missing sound \(effect.rawValue)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = effect.volume
            player.prepareToPlay()
            players[effect] = player
            return player
        } catch {
            AppLogger.control.error("Can't load sound \(effect.rawValue): \(error.localizedDescription)")
            return nil
        }
    }
}
