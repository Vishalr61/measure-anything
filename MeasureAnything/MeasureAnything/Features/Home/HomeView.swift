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
    @State private var homeTab: BottomNav.Tab = .convert

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
        VStack(spacing: 0) {
            Group {
                switch homeTab {
                case .convert:
                    convertTab
                case .favourites:
                    favouritesTab
                case .settings:
                    settingsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNav(selected: $homeTab, selectionTint: categoryAccent)
        }
        .background(Color(.systemGroupedBackground))
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

    private var convertTab: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
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
            .navigationBarTitleDisplayMode(.inline)
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
                        Haptics.tap()
                        showTaxonomySearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#5F5E5A"))
                    }
                    .buttonStyle(ConverterPressingButtonStyle())
                    .accessibilityLabel("Search")
                    .accessibilityHint("Opens taxonomy search")

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
        }
    }

    private var favouritesTab: some View {
        FavoritesListView(
            registry: vm.currentRegistry,
            onSelect: { fav in
                vm.applyFavoriteRestore(
                    categoryRaw: fav.categoryRaw,
                    fromID: fav.fromUnitID,
                    toID: fav.toUnitID
                )
                homeTab = .convert
            },
            presentedAsSheet: false
        )
    }

    private var settingsTab: some View {
        SettingsTabView()
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
        let selected = vm.selectedCategory == category
        return CategoryChip(
            category: category,
            displayName: display.displayName,
            accent: ConverterCategoryAccent.accent(for: category),
            isSelected: selected,
            onTap: {
                Haptics.tap()
                vm.selectedCategory = category
            }
        )
    }

}

#Preview {
    let taxonomy = AppTaxonomyStore()
    HomeView(vm: ConverterViewModel(taxonomy: taxonomy))
        .environmentObject(taxonomy)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
