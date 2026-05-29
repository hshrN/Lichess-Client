import ChessKit
import SwiftUI

struct ChessBoardView: View {
  var state: ChessBoardState
  var isInteractionEnabled = true
  var syncingMessage: String?
  var onSelectSquare: (Square) -> Void

  @AppStorage(AppPreferences.pieceThemeKey) private var pieceThemeRawValue = PieceTheme.rhosgfx.rawValue
  @AppStorage(AppPreferences.boardStyleKey) private var boardStyleRawValue = BoardStyle.walnut.rawValue

  var body: some View {
    GeometryReader { proxy in
      let boardLength = min(proxy.size.width, proxy.size.height)
      let gutterLength = max(14, boardLength * 0.052)
      let squareLength = (boardLength - gutterLength * 2) / 8

      ZStack {
        boardStyle.frameGradient

        boardContent(squareLength: squareLength, gutterLength: gutterLength)
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .clipShape(.rect(cornerRadius: 8))
    .opacity(isInteractionEnabled ? 1 : 0.72)
    .allowsHitTesting(isInteractionEnabled)
    .overlay {
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .stroke(.black.opacity(0.14), lineWidth: 1)

        if let syncingMessage {
          Text(syncingMessage)
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground).opacity(0.92), in: .capsule)
        }
      }
    }
    .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
    .animation(.snappy(duration: 0.24), value: state.lastMove)
    .animation(.smooth(duration: 0.18), value: state.selectedSquare)
    .animation(.smooth(duration: 0.18), value: state.legalTargets)
  }

  private func squareView(_ square: Square, length: CGFloat) -> some View {
    let piece = state.piece(at: square)
    let isSelected = state.selectedSquare == square
    let isTarget = state.legalTargets.contains(square)
    let isLastMoveSquare = state.lastMove?.start == square || state.lastMove?.end == square
    let isCheckedKingSquare = state.checkedKingSquare == square

    return Button {
      onSelectSquare(square)
    } label: {
      ZStack {
        Rectangle()
          .fill(square.color == .light ? boardStyle.lightSquare : boardStyle.darkSquare)

        if isLastMoveSquare {
          Rectangle()
            .fill(Color.yellow.opacity(0.18))
        }

        if isCheckedKingSquare {
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.red.opacity(0.28))
            .padding(3)
        }

        if isSelected {
          RoundedRectangle(cornerRadius: 6)
            .stroke(Color.white.opacity(0.9), lineWidth: 3)
            .padding(3)
        } else if isTarget {
          Circle()
            .fill(piece == nil ? Color.black.opacity(0.2) : Color.clear)
            .frame(width: 18, height: 18)

          if piece != nil {
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color.black.opacity(0.28), lineWidth: 3)
              .padding(3)
          }
        }

        pieceImage(piece, isSelected: isSelected)
      }
      .frame(width: length, height: length)
      .contentShape(.rect)
    }
    .frame(width: length, height: length)
    .buttonStyle(.plain)
    .sensoryFeedback(.selection, trigger: state.selectedSquare == square)
    .accessibilityLabel(accessibilityLabel(square: square, piece: piece, isTarget: isTarget))
  }

  @ViewBuilder
  private func pieceImage(_ piece: Piece?, isSelected: Bool) -> some View {
    if let piece,
       let image = ChessAssetImage.uiImage(theme: pieceTheme, imageName: pieceTheme.imageName(for: piece)) {
      Image(uiImage: image.withRenderingMode(.alwaysOriginal))
        .resizable()
        .renderingMode(.original)
        .interpolation(.high)
        .scaledToFit()
        .padding(4)
        .scaleEffect(isSelected ? 1.06 : 1)
        .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
    } else if let piece {
      Text(fallbackSymbol(for: piece))
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(piece.color == .white ? Color.white : Color.black)
        .minimumScaleFactor(0.7)
        .padding(4)
    }
  }

  private func boardContent(squareLength: CGFloat, gutterLength: CGFloat) -> some View {
    VStack {
      Color.clear
        .frame(height: gutterLength)

      HStack(spacing: 0) {
        rankLabels(squareLength: squareLength, gutterLength: gutterLength)
          .frame(width: gutterLength)

        VStack(spacing: 0) {
          ForEach(0..<8, id: \.self) { row in
            HStack(spacing: 0) {
              ForEach(0..<8, id: \.self) { column in
                let square = state.orderedSquares[row * 8 + column]
                squareView(square, length: squareLength)
              }
            }
          }
        }

        Color.clear
          .frame(width: gutterLength)
      }

      HStack(spacing: 0) {
        Color.clear
          .frame(width: gutterLength)

        fileLabels(squareLength: squareLength, gutterLength: gutterLength)

        Color.clear
          .frame(width: gutterLength)
      }
      .frame(height: gutterLength)
    }
  }

  private func rankLabels(squareLength: CGFloat, gutterLength: CGFloat) -> some View {
    VStack(spacing: 0) {
      ForEach(displayRanks, id: \.self) { rank in
        Text("\(rank)")
          .font(coordinateFont)
          .foregroundStyle(boardStyle.coordinateColor)
          .frame(width: gutterLength, height: squareLength)
      }
    }
  }

  private func fileLabels(squareLength: CGFloat, gutterLength: CGFloat) -> some View {
    HStack(spacing: 0) {
      ForEach(displayFiles, id: \.self) { file in
        Text(file.rawValue)
          .font(coordinateFont)
          .foregroundStyle(boardStyle.coordinateColor)
          .frame(width: squareLength, height: gutterLength)
      }
    }
  }

  private var coordinateFont: Font {
    .system(size: 10, weight: .semibold, design: .rounded)
  }

  private var pieceTheme: PieceTheme {
    PieceTheme(rawValue: pieceThemeRawValue) ?? .rhosgfx
  }

  private var boardStyle: BoardStyle {
    BoardStyle(rawValue: boardStyleRawValue) ?? .walnut
  }

  private var displayFiles: [Square.File] {
    let files = (1...8).map(Square.File.init)
    return state.isFlipped ? Array(files.reversed()) : files
  }

  private var displayRanks: [Int] {
    state.isFlipped ? Array(1...8) : Array((1...8).reversed())
  }

  private func accessibilityLabel(square: Square, piece: Piece?, isTarget: Bool) -> String {
    if let piece {
      return "\(piece.color.description) \(piece.kind.description), \(square.notation)"
    }
    if isTarget {
      return "Legal move, \(square.notation)"
    }
    return square.notation
  }

  private func fallbackSymbol(for piece: Piece) -> String {
    switch (piece.color, piece.kind) {
    case (.white, .king): "♔"
    case (.white, .queen): "♕"
    case (.white, .rook): "♖"
    case (.white, .bishop): "♗"
    case (.white, .knight): "♘"
    case (.white, .pawn): "♙"
    case (.black, .king): "♚"
    case (.black, .queen): "♛"
    case (.black, .rook): "♜"
    case (.black, .bishop): "♝"
    case (.black, .knight): "♞"
    case (.black, .pawn): "♟"
    }
  }
}
