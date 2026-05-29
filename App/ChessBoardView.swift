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
      let framePadding = max(6, boardLength * 0.025)
      let squareLength = (boardLength - framePadding * 2) / 8

      ZStack {
        boardStyle.frameGradient

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
        .padding(framePadding)
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
        coordinateLabel(for: square)
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
      Image(uiImage: image)
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .padding(4)
        .scaleEffect(isSelected ? 1.06 : 1)
        .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
    } else if let piece {
      Text(fallbackSymbol(for: piece))
        .font(.system(size: 28, weight: .semibold))
        .minimumScaleFactor(0.7)
        .padding(4)
    }
  }

  private func coordinateLabel(for square: Square) -> some View {
    VStack {
      Spacer()
      HStack {
        if showFile(for: square) {
          Text(square.file.rawValue)
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(boardStyle.coordinateColor)
            .padding(4)
        }
        Spacer()
      }
    }
    .overlay(alignment: .topTrailing) {
      if showRank(for: square) {
        Text("\(square.rank.value)")
          .font(.system(size: 9, weight: .medium, design: .rounded))
          .foregroundStyle(boardStyle.coordinateColor)
          .padding(4)
      }
    }
  }

  private var pieceTheme: PieceTheme {
    PieceTheme(rawValue: pieceThemeRawValue) ?? .rhosgfx
  }

  private var boardStyle: BoardStyle {
    BoardStyle(rawValue: boardStyleRawValue) ?? .walnut
  }

  private func showFile(for square: Square) -> Bool {
    state.isFlipped ? square.rank.value == 8 : square.rank.value == 1
  }

  private func showRank(for square: Square) -> Bool {
    state.isFlipped ? square.file == .h : square.file == .a
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
