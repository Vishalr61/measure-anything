import SwiftData
import SwiftUI
import MeasureAnythingCore

/// Single-page conversion workspace: discovery chrome, category pills, live converter, and optional shortcuts below.
struct HomeView: View {
    private enum HomeScrollTarget {
        static let converter = "converterWorkspace"
    }

    @Query(sort: \FavoriteConversion.createdAt, order: .reverse) private var favorites: [FavoriteConversion]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var vm: ConverterViewModel
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @State private var showTaxonomySearch = false
    @State private var showFavorites = false
    @State private var showCustomUnitForm = false
    @State private var scrollToConverterToken = 0

    private var categoryAccent: Color {
        ConverterCategoryAccent.accent(for: vm.selectedCategory)
    }

    private var isCurrentPairAlreadyFavorite: Bool {
        favorites.contains {
            $0.categoryRaw == vm.selectedCategory.rawValue
                && $0.fromUnitID == vm.selectedFromUnitID
                && $0.toUnitID == vm.selectedToUnitID
        }
    }

    private var canSaveFavoriteTap: Bool {
        vm.canSaveCurrentPairAsFavorite && !isCurrentPairAlreadyFavorite
    }

    /// Keep absurd mode on a valid taxonomy category.
    private func ensureSelectedCategoryIsValid() {
        if !vm.categories.contains(vm.selectedCategory), let first = vm.categories.first {
            vm.selectedCategory = first
        }
    }

    private func saveCurrentPairAsFavorite() {
        guard vm.canSaveCurrentPairAsFavorite, !isCurrentPairAlreadyFavorite else { return }
        let fav = FavoriteConversion(
            categoryRaw: vm.selectedCategory.rawValue,
            fromUnitID: vm.selectedFromUnitID,
            toUnitID: vm.selectedToUnitID
        )
        modelContext.insert(fav)
        try? modelContext.save()
        Haptics.favorite()
    }

    private func focusConverterFromAbsurdShortcut() {
        scrollToConverterToken &+= 1
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
                        dashboardHeader
                            .padding(.horizontal, ConverterLayout.horizontalInset)

                        searchBarButton
                            .padding(.horizontal, ConverterLayout.horizontalInset)

                        categoryPillBar

                        ConverterWorkspaceBody(
                            showsCategoryPicker: false,
                            showCustomUnitForm: $showCustomUnitForm,
                            vm: vm
                        )
                        .id(HomeScrollTarget.converter)
                    }
                    .padding(.bottom, ConverterLayout.rhythm24)
                }
                .onChange(of: scrollToConverterToken) { _, _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(HomeScrollTarget.converter, anchor: .top)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Measure Anything")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showFavorites = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.body.weight(.medium))
                            .imageScale(.medium)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(FavoritesToolbarButtonStyle())
                    .accessibilityLabel("View favorites")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        saveCurrentPairAsFavorite()
                    } label: {
                        Image(systemName: isCurrentPairAlreadyFavorite ? "star.fill" : "star")
                            .font(.body.weight(.regular))
                            .imageScale(.medium)
                            .foregroundStyle(isCurrentPairAlreadyFavorite ? categoryAccent.opacity(0.95) : Color.secondary)
                    }
                    .disabled(!canSaveFavoriteTap)
                    .buttonStyle(ConverterPressingButtonStyle())
                    .accessibilityLabel(isCurrentPairAlreadyFavorite ? "Already a favorite" : "Save as favorite")

                    if vm.selectedMode != .normal {
                        Button {
                            Haptics.tap()
                            vm.selectedMode = .custom
                            showCustomUnitForm = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.body.weight(.regular))
                                .imageScale(.medium)
                        }
                        .buttonStyle(ConverterPressingButtonStyle())
                        .accessibilityLabel("Add custom unit")
                    }
                }
            }
            .sheet(isPresented: $showTaxonomySearch) {
                TaxonomySearchView { itemId in
                    if let route = taxonomyStore.converterRoute(forTaxonomyItemId: itemId) {
                        vm.applyTaxonomyRoute(route)
                    }
                    showTaxonomySearch = false
                }
                .environmentObject(taxonomyStore)
            }
            .sheet(isPresented: $showFavorites) {
                FavoritesListView(registry: vm.currentRegistry) { fav in
                    vm.applyFavoriteRestore(
                        categoryRaw: fav.categoryRaw,
                        fromID: fav.fromUnitID,
                        toID: fav.toUnitID
                    )
                }
            }
        }
    }

    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: ConverterLayout.rhythm12) {
            Text("Convert anything, anytime.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .padding(.top, ConverterLayout.rhythm8)
    }

    private var searchBarButton: some View {
        Button {
            Haptics.tap()
            showTaxonomySearch = true
        } label: {
            HStack(spacing: ConverterLayout.rhythm12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("Search conversion tools…")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ConverterLayout.rhythm16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(ConverterLayout.strokeOpacitySubtle), lineWidth: ConverterLayout.strokeHairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search")
        .accessibilityHint("Opens taxonomy search")
    }

    private var categoryPillBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ConverterLayout.rhythm8) {
                ForEach(vm.categories, id: \.self) { category in
                    categoryPill(category)
                }
            }
            .padding(.horizontal, ConverterLayout.horizontalInset)
            .padding(.vertical, 2)
        }
    }

    private func categoryPill(_ category: UnitCategory) -> some View {
        let display = taxonomyStore.categoryDisplay(for: category)
        let accent = ConverterCategoryAccent.accent(for: category)
        let selected = vm.selectedCategory == category
        return Button {
            Haptics.tap()
            vm.selectedCategory = category
        } label: {
            Text(display.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, ConverterLayout.rhythm16)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? accent : Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            selected ? accent.opacity(0.35) : Color.primary.opacity(ConverterLayout.strokeOpacitySubtle),
                            lineWidth: ConverterLayout.strokeHairline
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(display.displayName) category")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

}

#Preview {
    let taxonomy = AppTaxonomyStore()
    HomeView(vm: ConverterViewModel(taxonomy: taxonomy))
        .environmentObject(taxonomy)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
