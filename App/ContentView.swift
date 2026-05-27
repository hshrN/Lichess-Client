import SwiftUI

struct ContentView: View {
  @State private var model = LichessClientModel()
  @State private var showingSettings = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          if model.isInGame {
            LiveBoardView(model: model)
          } else {
            RapidHomeView(model: model) {
              showingSettings = true
            }
          }
        }
        .frame(maxWidth: .infinity)
        .padding()
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Rapid")
      .toolbar {
        if model.isInGame {
          ToolbarItem(placement: .topBarLeading) {
            Button("Home", systemImage: "chevron.left") {
              model.returnHome()
            }
          }
        }

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
