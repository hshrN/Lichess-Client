import ChessKit
import SwiftUI

enum PieceTheme: String, CaseIterable, Identifiable {
  case rhosgfx
  case staunton
  case fantasy
  case spatial
  case celtic

  var id: String { rawValue }

  var title: String {
    switch self {
    case .rhosgfx: "Rhosgfx"
    case .staunton: "Staunton"
    case .fantasy: "Fantasy"
    case .spatial: "Spatial"
    case .celtic: "Celtic"
    }
  }

  var resourceFolder: String {
    switch self {
    case .rhosgfx: "Pieces/Rhosgfx"
    case .staunton: "Pieces/Staunton"
    case .fantasy: "Pieces/Fantasy"
    case .spatial: "Pieces/Spatial"
    case .celtic: "Pieces/Celtic"
    }
  }

  var resourcePrefix: String {
    switch self {
    case .rhosgfx: "rhosgfx_"
    case .staunton: "staunton_"
    case .fantasy: "fantasy_"
    case .spatial: "spatial_"
    case .celtic: "celtic_"
    }
  }

  func imageName(for piece: Piece) -> String {
    "\(piece.color == .white ? "w" : "b")\(pieceLetter(for: piece.kind))"
  }

  private func pieceLetter(for kind: Piece.Kind) -> String {
    switch kind {
    case .king: "K"
    case .queen: "Q"
    case .rook: "R"
    case .bishop: "B"
    case .knight: "N"
    case .pawn: "P"
    }
  }
}

enum BoardStyle: String, CaseIterable, Identifiable {
  case walnut
  case slate
  case paper

  var id: String { rawValue }

  var title: String {
    switch self {
    case .walnut: "Walnut"
    case .slate: "Slate"
    case .paper: "Paper"
    }
  }

  var lightSquare: Color {
    switch self {
    case .walnut: Color(red: 0.90, green: 0.84, blue: 0.73)
    case .slate: Color(red: 0.86, green: 0.88, blue: 0.91)
    case .paper: Color(red: 0.95, green: 0.92, blue: 0.84)
    }
  }

  var darkSquare: Color {
    switch self {
    case .walnut: Color(red: 0.39, green: 0.28, blue: 0.20)
    case .slate: Color(red: 0.40, green: 0.46, blue: 0.54)
    case .paper: Color(red: 0.55, green: 0.47, blue: 0.34)
    }
  }

  var frameGradient: LinearGradient {
    switch self {
    case .walnut:
      LinearGradient(colors: [Color(red: 0.20, green: 0.14, blue: 0.10), Color(red: 0.33, green: 0.24, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .slate:
      LinearGradient(colors: [Color(red: 0.22, green: 0.25, blue: 0.30), Color(red: 0.34, green: 0.39, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .paper:
      LinearGradient(colors: [Color(red: 0.58, green: 0.46, blue: 0.31), Color(red: 0.73, green: 0.63, blue: 0.46)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
  }

  var coordinateColor: Color {
    switch self {
    case .walnut, .slate: Color.white.opacity(0.86)
    case .paper: Color.black.opacity(0.66)
    }
  }
}

enum SoundTheme: String, CaseIterable, Identifiable {
  case classic

  var id: String { rawValue }
  var title: String { "Classic" }
}

enum AppPreferences {
  static let pieceThemeKey = "pieceTheme"
  static let boardStyleKey = "boardStyle"
  static let soundThemeKey = "soundTheme"
  static let soundEnabledKey = "soundEnabled"

  static var soundEnabled: Bool {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: soundEnabledKey) == nil {
      return true
    }
    return defaults.bool(forKey: soundEnabledKey)
  }
}
