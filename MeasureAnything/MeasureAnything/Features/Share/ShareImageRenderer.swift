import SwiftUI
import UIKit

enum ShareImageRenderer {
    @MainActor
    static func renderCard(
        inputFormatted: String,
        fromName: String,
        outputFormatted: String,
        toName: String,
        meme: String?
    ) -> UIImage? {
        let view = ExportResultCardView(
            inputFormatted: inputFormatted,
            fromName: fromName,
            outputFormatted: outputFormatted,
            toName: toName,
            meme: meme
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = Self.renderScale
        return renderer.uiImage
    }

    /// Avoid `UIScreen.main` (deprecated iOS 26+); use an attached window scene when available.
    private static var renderScale: CGFloat {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            return windowScene.screen.scale
        }
        return 3.0
    }
}
