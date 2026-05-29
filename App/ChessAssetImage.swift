import SwiftUI
import UIKit

enum ChessAssetImage {
  private static let cache = NSCache<NSString, UIImage>()

  static func uiImage(theme: PieceTheme, imageName: String) -> UIImage? {
    let cacheKey = "\(theme.rawValue)-\(imageName)" as NSString
    if let cached = cache.object(forKey: cacheKey) {
      return cached
    }

    let assetName = "\(theme.resourcePrefix)\(imageName)"
    let image: UIImage?

    if let image = UIImage(named: assetName) {
      let processed = processedImage(from: image)
      cache.setObject(processed, forKey: cacheKey)
      return processed
    }

    if let url = Bundle.main.url(forResource: assetName, withExtension: "png", subdirectory: theme.resourceFolder) {
      image = UIImage(contentsOfFile: url.path)
    } else if let url = Bundle.main.url(forResource: assetName, withExtension: "png") {
      image = UIImage(contentsOfFile: url.path)
    } else {
      image = nil
    }

    guard let image else {
      return nil
    }

    let processed = processedImage(from: image)
    cache.setObject(processed, forKey: cacheKey)
    return processed
  }

  private static func processedImage(from image: UIImage) -> UIImage {
    guard let cgImage = image.cgImage else {
      return image
    }

    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

    guard let context = CGContext(
      data: &pixels,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return image
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var queue: [Int] = []
    queue.reserveCapacity(width * 2 + height * 2)
    var visited = [Bool](repeating: false, count: width * height)

    func enqueueIfBackground(x: Int, y: Int) {
      let index = y * width + x
      guard !visited[index] else { return }
      let pixelIndex = index * bytesPerPixel
      let red = pixels[pixelIndex]
      let green = pixels[pixelIndex + 1]
      let blue = pixels[pixelIndex + 2]
      let alpha = pixels[pixelIndex + 3]
      guard alpha > 0, red >= 245, green >= 245, blue >= 245 else { return }
      visited[index] = true
      queue.append(index)
    }

    for x in 0..<width {
      enqueueIfBackground(x: x, y: 0)
      enqueueIfBackground(x: x, y: height - 1)
    }
    for y in 0..<height {
      enqueueIfBackground(x: 0, y: y)
      enqueueIfBackground(x: width - 1, y: y)
    }

    var didChange = false
    var cursor = 0
    while cursor < queue.count {
      let index = queue[cursor]
      cursor += 1

      let pixelIndex = index * bytesPerPixel
      pixels[pixelIndex + 3] = 0
      didChange = true

      let x = index % width
      let y = index / width
      if x > 0 { enqueueIfBackground(x: x - 1, y: y) }
      if x + 1 < width { enqueueIfBackground(x: x + 1, y: y) }
      if y > 0 { enqueueIfBackground(x: x, y: y - 1) }
      if y + 1 < height { enqueueIfBackground(x: x, y: y + 1) }
    }

    guard didChange, let output = context.makeImage() else {
      return image
    }

    return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation)
  }
}
