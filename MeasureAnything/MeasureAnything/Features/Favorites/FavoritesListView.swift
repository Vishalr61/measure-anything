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

    var body: some View {
        let itemCount = favorites.count
        let detent: PresentationDetent = itemCount <= 3 ? .medium : .large

        NavigationStack {
            VStack(spacing: 0) {
                if presentedAsSheet {
                    VStack(spacing: 0) {
                        HStack {
                            Button("Done") { dismiss() }
                                .font(.body)
                                .foregroundStyle(Color.secondary)
                                .buttonStyle(.plain)

                            Spacer()

                            Text("Favourites")
                                .font(.headline)

                            Spacer()

                            Text("Done")
                                .font(.body)
                                .opacity(0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 14)

                        Divider()
                    }
                }

                Group {
                    if favorites.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(favorites) { fav in
                                favoriteRow(fav)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
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
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .listRowSpacing(6)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
        }
        .presentationDetents([.medium, .large], selection: .constant(detent))
        .presentationDragIndicator(.visible)
    }
}

private extension FavoritesListView {
    func favoriteRow(_ fav: FavoriteConversion) -> some View {
        let category = UnitCategory(rawValue: fav.categoryRaw) ?? .length
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
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: categorySymbolName(category))
                            .font(.system(size: 14))
                            .foregroundStyle(accent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(fromName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(.label))
                    + Text(" → ")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(.tertiaryLabel))
                    + Text(toName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(.label))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(categoryDisplayName(category))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(accent.opacity(0.12))
                    .overlay(
                        Capsule()
                            .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
                    )
                    .clipShape(Capsule())
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(FavoritesRowPressButtonStyle())
        .disabled(!restorable)
        .opacity(restorable ? 1 : 0.55)
    }

    func categorySymbolName(_ category: UnitCategory) -> String {
        switch category {
        case .length: return "ruler"
        case .mass: return "scalemass"
        case .time: return "clock"
        case .temperature: return "thermometer"
        case .volume: return "drop.fill"
        }
    }

    struct FavoritesRowPressButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(configuration.isPressed ? Color(.systemGray6) : Color.clear)
        }
    }

    func categoryDisplayName(_ category: UnitCategory) -> String {
        switch category {
        case .length: return "Length"
        case .mass: return "Mass"
        case .time: return "Time"
        case .temperature: return "Temperature"
        case .volume: return "Volume"
        }
    }

    var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "star")
                .font(.system(size: 32))
                .foregroundStyle(Color(.tertiaryLabel))

            Text("No favourites yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Text("Tap the star on any conversion to save it")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}
