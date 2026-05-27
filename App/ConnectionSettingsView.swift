import SwiftUI

struct ConnectionSettingsView: View {
  @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
  @Bindable var model: LichessClientModel

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Account")
        .font(.headline)

      HStack(spacing: 12) {
        Image(systemName: model.isConfigured ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.questionmark")
          .font(.title2)
          .foregroundStyle(.tint)

        VStack(alignment: .leading, spacing: 2) {
          Text(model.accountLabel)
            .font(.subheadline.weight(.semibold))
          Text(model.isConfigured ? "Authorized with Lichess OAuth" : "Sign in with Lichess to enable play and challenges.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }

      VStack(alignment: .leading, spacing: 8) {
        RequirementRow(text: "Authorization code flow with PKCE")
        RequirementRow(text: "Scopes: board play and challenges")
        RequirementRow(text: "No engine assistance or move suggestions")
        RequirementRow(text: "Rapid seeks only")
      }

      if let authError = model.authError {
        Text(authError)
          .font(.caption)
          .foregroundStyle(.red)
      }

      if model.isConfigured {
        HStack(spacing: 10) {
          Button("Check Stream", systemImage: "antenna.radiowaves.left.and.right") {
            model.refreshMockStream()
          }
          .buttonStyle(.borderedProminent)

          Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
            Task {
              await model.signOut()
            }
          }
          .buttonStyle(.bordered)
        }
      } else {
        Button("Sign In with Lichess", systemImage: model.isAuthenticating ? "hourglass" : "person.crop.circle.badge.plus") {
          Task {
            await model.signIn()
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.isAuthenticating)
      }

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
