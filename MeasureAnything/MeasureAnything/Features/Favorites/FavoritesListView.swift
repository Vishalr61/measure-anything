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
    /// When `false`, embedded in the main tab bar (no Done toolbar, no dismiss on select).
    var presentedAsSheet: Bool = true
    @State private var sheetDetent: PresentationDetent = .large

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(sectionOrder, id: \.self) { cat in
                                if let rows = favoritesByCategory[cat], !rows.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        sectionHeader(for: cat)
                                            .padding(.bottom, 4)

                                        ForEach(rows) { fav in
                                            favoriteRow(fav, category: cat)
                                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                    Button(role: .destructive) {
                                                        Haptics.tap()
                                                        modelContext.delete(fav)
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if presentedAsSheet {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                            .font(.body)
                            .foregroundStyle(Color.secondary)
                            .buttonStyle(.plain)
                            .frame(minWidth: 56, alignment: .center)
                            .lineLimit(1)
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Favourites")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large], selection: $sheetDetent)
        .presentationDragIndicator(.visible)
        .onAppear {
            sheetDetent = favorites.count > 4 ? .large : .medium
        }
    }
}

private extension FavoritesListView {
    var sectionOrder: [UnitCategory] { UnitCategory.allCases }

    var favoritesByCategory: [UnitCategory: [FavoriteConversion]] {
        Dictionary(grouping: favorites) { fav in
            UnitCategory(rawValue: fav.categoryRaw) ?? .length
        }
    }

    func sectionHeader(for category: UnitCategory) -> some View {
        let accent = ConverterCategoryAccent.accent(for: category)
        return Text(category.rawValue.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(accent.opacity(0.6))
            .padding(.leading, 4)
    }

    func favoriteRow(_ fav: FavoriteConversion, category: UnitCategory) -> some View {
        let accent = ConverterCategoryAccent.accent(for: category)
        let fromName = (try? registry.unit(id: fav.fromUnitID))?.name ?? "?"
        let toName = (try? registry.unit(id: fav.toUnitID))?.name ?? "?"
        let restorable = fav.isRestorable(registry: registry)

        return Button {
            guard restorable else { return }
            Haptics.tap()
            onSelect(fav)
            if presentedAsSheet {
                dismiss()
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent)
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(fromName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text("→")
                            .font(.system(size: 10))
                            .foregroundStyle(accent)
                        Text(toName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: categorySymbolName(category))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(accent)
                    )
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!restorable)
        .opacity(restorable ? 1 : 0.55)
    }

    func categorySymbolName(_ category: UnitCategory) -> String {
        switch category {
        case .length: return "ruler"
        case .mass: return "scalemass"
        case .time: return "clock"
        case .temperature: return "thermometer"
        case .volume: return "drop"
        }
    }

    var emptyState: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "star")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.secondary)
                )

            Text("No favourites yet")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Save a conversion using the star button")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}
