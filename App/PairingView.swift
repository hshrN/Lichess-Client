import SwiftUI

struct PairingView: View {
  var model: LichessClientModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Seek")
        .font(.headline)

      ForEach(SeekPreset.defaults) { preset in
        Button {
          Task {
            await model.seek(preset)
          }
        } label: {
          HStack(spacing: 12) {
            Image(systemName: preset.days == nil ? "timer" : "calendar")
              .foregroundStyle(.tint)
              .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
              Text(preset.title)
                .font(.subheadline.weight(.semibold))
              Text(preset.rated ? "Rated" : "Casual")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .font(.caption.weight(.bold))
              .foregroundStyle(.tertiary)
          }
          .padding(14)
          .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
