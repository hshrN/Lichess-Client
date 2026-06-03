import SwiftUI

struct ChessRulesLabView: View {
  @State private var game = ChessPreviewGameModel()
  @State private var selectedScenario = ChessRulesScenario.defaults[0]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Picker("Scenario", selection: $selectedScenario) {
          ForEach(ChessRulesScenario.defaults) { scenario in
            Text(scenario.title).tag(scenario)
          }
        }
        .pickerStyle(.menu)

        Text(selectedScenario.detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        ChessBoardView(
          state: game.chessBoardState,
          isInteractionEnabled: true,
          syncingMessage: nil,
          onSelectSquare: game.selectBoardSquare
        )

        HStack(spacing: 10) {
          stat(title: "State", value: game.statusDetail)
          stat(title: "Moves", value: game.moveCountLabel)
        }

        HStack(spacing: 10) {
          Button("Reset", systemImage: "arrow.counterclockwise") {
            game.reset()
          }
          .buttonStyle(.bordered)

          Button("Flip", systemImage: "arrow.triangle.2.circlepath") {
            game.flipBoard()
          }
          .buttonStyle(.bordered)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Rules Lab")
    .onAppear {
      loadSelectedScenario()
    }
    .onChange(of: selectedScenario) {
      loadSelectedScenario()
    }
  }

  private func stat(title: String, value: String) -> some View {
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

  private func loadSelectedScenario() {
    game.load(position: selectedScenario.position, selectedSquare: selectedScenario.focusSquare)
  }
}
