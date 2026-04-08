import SwiftUI
import SwiftData
import MeasureAnythingCore

/// Simple list of saved pairs; tap to restore, swipe or button to delete.
struct FavoritesListView: View {
    @Query(sort: \FavoriteConversion.createdAt, order: .reverse) private var favorites: [FavoriteConversion]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let registry: UnitRegistry
    let onSelect: (FavoriteConversion) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    ContentUnavailableView(
                        "No favorites yet",
                        systemImage: "star",
                        description: Text("Use the star on the converter to save a unit pair.")
                    )
                } else {
                    List {
                        ForEach(favorites) { fav in
                            Button {
                                if fav.isRestorable(registry: registry) {
                                    onSelect(fav)
                                    dismiss()
                                }
                            } label: {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(fav.displayTitle(registry: registry))
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(fav.isRestorable(registry: registry) ? .primary : .secondary)
                                        Text(fav.displaySubtitle())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if !fav.isRestorable(registry: registry) {
                                        Text("Unavailable")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .disabled(!fav.isRestorable(registry: registry))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(fav)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
