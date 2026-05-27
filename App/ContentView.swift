import SwiftUI

struct ContentView: View {
  @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
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

          Button("Account", systemImage: model.isConfigured ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle") {
            showingSettings = true
          }
          .labelStyle(.iconOnly)
          .accessibilityLabel("Lichess account")
        }
      }
      .sheet(isPresented: $showingSettings) {
        NavigationStack {
          ConnectionSettingsView(model: model)
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Lichess Account")
            .toolbar {
              ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                  showingSettings = false
                }
              }
            }
        }
      }
      .preferredColorScheme(preferredColorScheme)
    }
  }

  private var preferredColorScheme: ColorScheme? {
    switch AppearanceMode(rawValue: appearanceModeRaw) ?? .system {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}
