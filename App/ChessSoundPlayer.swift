import AVFoundation
import AudioToolbox
import ChessKit
import Foundation

@MainActor
final class ChessSoundPlayer {
  static let shared = ChessSoundPlayer()

  private var players: [String: AVAudioPlayer] = [:]
  private let fallbackSystemSounds: [String: SystemSoundID] = [
    "move": 1104,
    "capture": 1157,
    "check": 1114
  ]

  func play(for move: Move) {
    guard AppPreferences.soundEnabled else {
      return
    }

    let soundName: String
    switch move.checkState {
    case .check, .checkmate:
      soundName = "check"
    case .none, .stalemate:
      switch move.result {
      case .capture:
        soundName = "capture"
      case .move, .castle:
        soundName = "move"
      }
    }

    play(named: soundName)
  }

  private func play(named name: String) {
    let player: AVAudioPlayer
    if let cached = players[name] {
      player = cached
    } else {
      guard let url = Bundle.main.url(forResource: "Sounds/\(name)", withExtension: "mp3"),
            let newPlayer = try? AVAudioPlayer(contentsOf: url) else {
        playFallback(named: name)
        return
      }
      newPlayer.prepareToPlay()
      players[name] = newPlayer
      player = newPlayer
    }

    player.currentTime = 0
    player.play()
  }

  private func playFallback(named name: String) {
    guard let soundID = fallbackSystemSounds[name] else {
      return
    }
    AudioServicesPlaySystemSound(soundID)
  }
}
