import SwiftUI
import UIKit

enum ChessAssetImage {
  static func uiImage(theme: PieceTheme, imageName: String) -> UIImage? {
    let assetName = "\(theme.resourcePrefix)\(imageName)"

    if let image = UIImage(named: assetName) {
      return image
    }

    if let url = Bundle.main.url(forResource: assetName, withExtension: "png") {
      return UIImage(contentsOfFile: url.path)
    }

    if let url = Bundle.main.url(forResource: imageName, withExtension: "png", subdirectory: theme.resourceFolder) {
      return UIImage(contentsOfFile: url.path)
    }

    return nil
  }
}
