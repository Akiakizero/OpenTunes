// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

extension NSImage {
    /// Copia quadrata di lato `side` pixel (riempimento al centro), con angoli arrotondati se `cornerFraction > 0`.
    func squareThumbnail(side: Int, cornerFraction: CGFloat = 0, inset: CGFloat = 0) -> NSImage? {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        let canvas = CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: inset, dy: inset)
        if cornerFraction > 0 {
            let radius = canvas.width * cornerFraction
            context.addPath(CGPath(roundedRect: canvas, cornerWidth: radius, cornerHeight: radius, transform: nil))
            context.clip()
        }
        // Riempimento: il lato corto dell'immagine copre tutto il quadrato.
        let scale = max(canvas.width / CGFloat(cg.width), canvas.height / CGFloat(cg.height))
        let size = CGSize(width: CGFloat(cg.width) * scale, height: CGFloat(cg.height) * scale)
        context.draw(cg, in: CGRect(x: canvas.midX - size.width / 2, y: canvas.midY - size.height / 2, width: size.width, height: size.height))
        guard let result = context.makeImage() else { return nil }
        return NSImage(cgImage: result, size: NSSize(width: side, height: side))
    }

    var pngData: Data? {
        guard let cg = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])
    }
}
