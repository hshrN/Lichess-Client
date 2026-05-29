import SwiftUI

struct ConnectionSettingsView: View {
  @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
  @AppStorage(AppPreferences.pieceThemeKey) private var pieceThemeRawValue = PieceTheme.rhosgfx.rawValue
  @AppStorage(AppPreferences.boardStyleKey) private var boardStyleRawValue = BoardStyle.walnut.rawValue
  @AppStorage(AppPreferences.soundEnabledKey) private var soundEnabled = AppPreferences.soundEnabled
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

      ViewThatFits(in: .horizontal) {
        HStack(alignment: .top, spacing: 16) {
          customizationControls
          boardPreview
        }

        VStack(alignment: .leading, spacing: 14) {
          boardPreview
            .frame(maxWidth: .infinity, alignment: .center)
          customizationControls
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
  }

  private var customizationControls: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Board")
        .font(.headline)

      Picker("Appearance", selection: $appearanceModeRaw) {
        ForEach(AppearanceMode.allCases) { mode in
          Text(mode.title).tag(mode.rawValue)
        }
      }
      .pickerStyle(.segmented)

      Picker("Board", selection: $boardStyleRawValue) {
        ForEach(BoardStyle.allCases) { style in
          Text(style.title).tag(style.rawValue)
        }
      }
      .pickerStyle(.segmented)

      Picker("Pieces", selection: $pieceThemeRawValue) {
        ForEach(PieceTheme.allCases) { theme in
          Text(theme.title).tag(theme.rawValue)
        }
      }
      .pickerStyle(.segmented)

      Toggle("Sounds", isOn: $soundEnabled)
    }
    .frame(minWidth: 230, maxWidth: .infinity, alignment: .leading)
  }

  private var boardPreview: some View {
    ChessBoardPreviewView()
      .frame(width: 178)
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
