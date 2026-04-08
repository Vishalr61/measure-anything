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
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
