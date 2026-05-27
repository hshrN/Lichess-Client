import SwiftUI

struct ContentView: View {
  @State private var model = LichessClientModel()
  @State private var section = ClientSection.board

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          HeaderPanel(model: model)

          Picker("Section", selection: $section) {
            ForEach(ClientSection.allCases) { section in
              Label(section.title, systemImage: section.systemImage)
                .tag(section)
            }
          }
          .pickerStyle(.segmented)

          Group {
            switch section {
            case .board:
              LiveBoardView(model: model)
            case .play:
              PairingView(model: model)
            case .challenges:
              ChallengesView(model: model)
            case .settings:
              ConnectionSettingsView(model: model)
            }
          }
        }
        .frame(maxWidth: .infinity)
        .padding()
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Lichess Board")
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button("Refresh", systemImage: "arrow.clockwise") {
            model.refreshMockStream()
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Refresh stream")
        }
      }
    }
  }
}
