import ChessKit
import SwiftUI

struct PromotionPickerView: View {
  var color: Piece.Color
  var onSelect: (PromotionPieceOption) -> Void
  var onCancel: () -> Void

  @AppStorage(AppPreferences.pieceThemeKey) private var pieceThemeRawValue = PieceTheme.rhosgfx.rawValue

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Choose Promotion")
        .font(.headline)

      HStack(spacing: 10) {
        ForEach(PromotionPieceOption.allCases) { option in
          Button {
            onSelect(option)
          } label: {
            VStack(spacing: 8) {
              pieceImage(for: option)
                .frame(width: 36, height: 36)
              Text(option.title)
                .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
          }
          .buttonStyle(.borderedProminent)
        }
      }

      Button("Cancel") {
        onCancel()
      }
      .buttonStyle(.bordered)
    }
    .padding(18)
  }

  @ViewBuilder
  private func pieceImage(for option: PromotionPieceOption) -> some View {
    if let image = ChessAssetImage.uiImage(theme: pieceTheme, imageName: imageName(for: option)) {
      Image(uiImage: image.withRenderingMode(.alwaysOriginal))
        .resizable()
        .renderingMode(.original)
        .interpolation(.high)
        .scaledToFit()
    } else {
      Text(symbol(for: option))
        .font(.system(size: 28, weight: .semibold))
    }
  }

  private var pieceTheme: PieceTheme {
    PieceTheme(rawValue: pieceThemeRawValue) ?? .rhosgfx
  }

  private func symbol(for option: PromotionPieceOption) -> String {
    switch (color, option) {
    case (.white, .queen): "♕"
    case (.white, .rook): "♖"
    case (.white, .bishop): "♗"
    case (.white, .knight): "♘"
    case (.black, .queen): "♛"
    case (.black, .rook): "♜"
    case (.black, .bishop): "♝"
    case (.black, .knight): "♞"
    default: "♕"
    }
  }

  private func imageName(for option: PromotionPieceOption) -> String {
    let prefix = color == .white ? "w" : "b"
    let suffix: String
    switch option {
    case .queen:
      suffix = "Q"
    case .rook:
      suffix = "R"
    case .bishop:
      suffix = "B"
    case .knight:
      suffix = "N"
    }
    return "\(prefix)\(suffix)"
  }
}
