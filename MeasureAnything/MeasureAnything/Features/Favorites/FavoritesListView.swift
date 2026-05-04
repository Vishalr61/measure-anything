import SwiftUI
import SwiftData
import MeasureAnythingCore

/// Simple list of saved pairs; tap to restore, swipe or button to delete.
struct FavoritesListView: View {
    @Query(sort: \FavoriteConversion.createdAt, order: .reverse) private var favorites: [FavoriteConversion]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let registry: UnitRegistry
    let accent: Color
    let onSelect: (FavoriteConversion) -> Void
    /// When `false`, embedded in the main tab bar (no Done toolbar, no dismiss on select).
    var presentedAsSheet: Bool = true

    var body: some View {
        let itemCount = favorites.count
        let detent: PresentationDetent = itemCount <= 3 ? .fraction(0.6) : .large

        NavigationStack {
            VStack(spacing: 0) {
                if presentedAsSheet {
                    VStack(spacing: 0) {
                        HStack {
                            Button("Done") { dismiss() }
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(accent)
                                .buttonStyle(.plain)
                                .padding(.leading, 12)

                            Spacer()

                            Text("Favourites")
                                .font(.system(size: 18, weight: .semibold))

                            Spacer()

                            Text("Done")
                                .font(.system(size: 18, weight: .semibold))
                                .padding(.leading, 12)
                                .opacity(0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 14)
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
                        .listRowSpacing(10)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
        }
        .presentationDetents([.fraction(0.6), .large], selection: .constant(detent))
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: categorySymbolName(category))
                            .font(.system(size: 18))
                            .foregroundStyle(accent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(fromName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(.label))
                    + Text(" → ")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(.tertiaryLabel))
                    + Text(toName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(.label))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(categoryDisplayName(category))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(accent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(accent.opacity(0.3), lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
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
        category.symbolName
    }

    struct FavoritesRowPressButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(configuration.isPressed ? Color(.systemGray6) : Color.clear)
        }
    }

    func categoryDisplayName(_ category: UnitCategory) -> String {
        category.displayName
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color(hex: "#D0D0C8"))
            Text("No favourites yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: "#1A1A1A"))
            Text("Tap the star on any unit to save it here.")
                .font(.system(size: 15))
                .foregroundStyle(Color(hex: "#6E6E6E"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}
