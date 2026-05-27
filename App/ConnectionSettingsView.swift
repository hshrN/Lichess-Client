import SwiftUI

struct ConnectionSettingsView: View {
  @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
  @Bindable var model: LichessClientModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Connection")
        .font(.headline)

      SecureField("Lichess API token", text: $model.accessToken)
        .textContentType(.password)
        .textFieldStyle(.roundedBorder)

      VStack(alignment: .leading, spacing: 8) {
        RequirementRow(text: "Board API compatible token")
        RequirementRow(text: "No engine assistance or move suggestions")
        RequirementRow(text: "Rapid seeks only")
      }

      Button("Check Stream", systemImage: "antenna.radiowaves.left.and.right") {
        model.refreshMockStream()
      }
      .buttonStyle(.borderedProminent)

      Divider()

      Picker("Appearance", selection: $appearanceModeRaw) {
        ForEach(AppearanceMode.allCases) { mode in
          Text(mode.title).tag(mode.rawValue)
        }
      }
      .pickerStyle(.segmented)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }
}

private struct RequirementRow: View {
  var text: String

  var body: some View {
    Label(text, systemImage: "checkmark.seal")
      .font(.subheadline)
      .foregroundStyle(.secondary)
  }
}
