import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct InviteQRCodeImage: View {
    let url: URL

    var body: some View {
        SwiftUI.Group {
            if let image = Self.render(url: url) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("QR code for Barabari group invite")
                    .accessibilityIdentifier("invite-qr")
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 96, weight: .medium))
                    .foregroundStyle(BarabariColors.textSecondary)
                    .accessibilityLabel("QR code unavailable")
                    .accessibilityIdentifier("invite-qr")
            }
        }
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    static func render(url: URL, scale: CGFloat = 8) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
