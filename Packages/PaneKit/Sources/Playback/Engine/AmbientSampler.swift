import CoreGraphics
import Domain
import Foundation
import ImageIO

/// Averages a tiny snapshot into the palette's grid.
enum AmbientSampler {
    static let sampleWidth = 32

    static func palette(fromImageAt url: URL) -> AmbientPalette? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return palette(from: image)
    }

    static func palette(from image: CGImage) -> AmbientPalette? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        // Redrawn into a known layout because libvlc's PNG may be RGB, RGBA or 16-bit depending on the chroma.
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let isDrawn = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard isDrawn else { return nil }

        var swatches: [AmbientPalette.Swatch] = []
        for row in 0..<AmbientPalette.rows {
            let top = row * height / AmbientPalette.rows
            let bottom = max((row + 1) * height / AmbientPalette.rows, top + 1)
            for column in 0..<AmbientPalette.columns {
                let leading = column * width / AmbientPalette.columns
                let trailing = max((column + 1) * width / AmbientPalette.columns, leading + 1)
                var sum = (red: 0, green: 0, blue: 0)
                for y in top..<min(bottom, height) {
                    for x in leading..<min(trailing, width) {
                        let offset = (y * width + x) * 4
                        sum.red += Int(pixels[offset])
                        sum.green += Int(pixels[offset + 1])
                        sum.blue += Int(pixels[offset + 2])
                    }
                }
                let count = Double((min(bottom, height) - top) * (min(trailing, width) - leading) * 255)
                swatches.append(AmbientPalette.Swatch(
                    red: Double(sum.red) / count,
                    green: Double(sum.green) / count,
                    blue: Double(sum.blue) / count
                ))
            }
        }
        return AmbientPalette(swatches: swatches)
    }
}
