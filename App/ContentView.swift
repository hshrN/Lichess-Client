import SwiftUI

struct ContentView: View {
  @State private var model = LichessClientModel()
  @State private var showingSettings = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          RapidHeaderView(model: model)
          RapidPairingStrip(model: model)
          LiveBoardView(model: model)
        }
        .frame(maxWidth: .infinity)
        .padding()
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Rapid")
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button("Refresh", systemImage: "arrow.clockwise") {
            model.refreshMockStream()
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Refresh stream")

          Button("Token", systemImage: "key") {
            showingSettings = true
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Token settings")
        }
      }
      .sheet(isPresented: $showingSettings) {
        NavigationStack {
          ConnectionSettingsView(model: model)
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Lichess Token")
            .toolbar {
              ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                  showingSettings = false
                }
              }
            }
        }
      }
    }
  }
}
