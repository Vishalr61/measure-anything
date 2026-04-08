import SwiftUI

/// Shared accessibility for taxonomy-backed picker segments (labels + optional hints).
enum TaxonomyDisplayModifiers {
    struct SegmentA11y: ViewModifier {
        let displayName: String
        let description: String?

        func body(content: Content) -> some View {
            if let description, !description.isEmpty {
                content
                    .accessibilityLabel(displayName)
                    .accessibilityHint(description)
            } else {
                content
                    .accessibilityLabel(displayName)
            }
        }
    }
}

extension View {
    /// VoiceOver label is `displayName`; hint is optional taxonomy description when non-empty.
    func taxonomyPickerSegmentAccessibility(displayName: String, description: String?) -> some View {
        modifier(TaxonomyDisplayModifiers.SegmentA11y(displayName: displayName, description: description))
    }
}
