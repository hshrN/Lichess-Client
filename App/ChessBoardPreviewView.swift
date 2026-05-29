import SwiftUI

struct ChessBoardPreviewView: View {
  @State private var game = ChessPreviewGameModel()
  @State private var showingGamePreview = false

  var body: some View {
    VStack(spacing: 12) {
      ChessBoardView(
        state: game.chessBoardState,
        isInteractionEnabled: true,
        syncingMessage: nil,
        onSelectSquare: game.selectBoardSquare
      )

      VStack(spacing: 8) {
        Text(game.statusDetail)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)

        Text(game.moveCountLabel)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }

      HStack(spacing: 8) {
        Button("Reset", systemImage: "arrow.counterclockwise") {
          game.reset()
        }
        .buttonStyle(.bordered)
        .disabled(!game.canReset)

        Button("Flip", systemImage: "arrow.triangle.2.circlepath") {
          game.flipBoard()
        }
        .buttonStyle(.bordered)
      }

      Button("Game Preview", systemImage: "arrow.up.left.and.arrow.down.right") {
        showingGamePreview = true
      }
      .buttonStyle(.borderedProminent)
      .frame(maxWidth: .infinity)
    }
    .fullScreenCover(isPresented: $showingGamePreview) {
      NavigationStack {
        ChessGamePreviewView(game: game)
      }
    }
  }
}

private struct ChessGamePreviewView: View {
  @Bindable var game: ChessPreviewGameModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        clockRow
        boardPanel
        summaryPanel
        moveListPanel
      }
      .frame(maxWidth: .infinity)
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Game Preview")
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button("Close") {
          dismiss()
        }
      }
    }
  }

  private var clockRow: some View {
    HStack(spacing: 12) {
      previewClock(name: "White", isActive: game.board.position.sideToMove == .white)
      previewClock(name: "Black", isActive: game.board.position.sideToMove == .black)
    }
  }

  private func previewClock(name: String, isActive: Bool) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(name)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("10:00")
        .font(.title3.monospacedDigit().weight(.semibold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(isActive ? Color.accentColor.opacity(0.14) : Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }

  private var boardPanel: some View {
    VStack(spacing: 10) {
      ChessBoardView(
        state: game.chessBoardState,
        isInteractionEnabled: true,
        syncingMessage: nil,
        onSelectSquare: game.selectBoardSquare
      )

      HStack(spacing: 10) {
        Button("Reset", systemImage: "arrow.counterclockwise") {
          game.reset()
        }
        .buttonStyle(.bordered)
        .disabled(!game.canReset)

        Button("Flip Board", systemImage: "arrow.triangle.2.circlepath") {
          game.flipBoard()
        }
        .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  private var summaryPanel: some View {
    HStack(spacing: 12) {
      previewStat(title: "State", value: game.statusDetail)
      previewStat(title: "Moves", value: game.moveCountLabel)
    }
  }

  private func previewStat(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }

  private var moveListPanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Moves", systemImage: "list.number")
        .font(.headline)

      if game.moves.isEmpty {
        Text("Play moves on the board to test piece sets, highlights, and sounds.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          ForEach(Array(movePairs.enumerated()), id: \.offset) { index, pair in
            HStack(alignment: .top, spacing: 8) {
              Text("\(index + 1).")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

              VStack(alignment: .leading, spacing: 2) {
                Text(pair.white)
                if let black = pair.black {
                  Text(black)
                }
              }
              .font(.caption.monospaced())

              Spacer(minLength: 0)
            }
            .padding(10)
            .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: 10))
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }

  private var movePairs: [MovePair] {
    stride(from: 0, to: game.moves.count, by: 2).map { index in
      MovePair(
        white: game.moves[index],
        black: index + 1 < game.moves.count ? game.moves[index + 1] : nil
      )
    }
  }
}

private struct MovePair {
  var white: String
  var black: String?
}
