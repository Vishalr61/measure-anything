import SwiftUI
import SwiftData
import MeasureAnythingCore

/// Standalone converter screen (previews and tooling). The app’s primary surface is `HomeView`, which embeds `ConverterWorkspaceBody` directly.
struct ConverterView: View {
    @Query(sort: \FavoriteConversion.createdAt, order: .reverse) private var favorites: [FavoriteConversion]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @ObservedObject var vm: ConverterViewModel
    @State private var showCustomUnitForm = false
    @State private var showFavorites = false
    @State private var showGlobalSearch = false
    @State private var mainTab: BottomNav.Tab = .convert

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

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch mainTab {
                case .convert:
                    convertTab
                case .favourites:
                    favouritesTab
                case .settings:
                    SettingsTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNav(selected: $mainTab, selectionTint: categoryAccent)
        }
        .background(Color(hex: "#F0F0F3"))
        .sheet(isPresented: $showGlobalSearch) {
            GlobalUnitSearchView(vm: vm)
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
            ScrollView {
                ConverterWorkspaceBody(
                    showsCategoryPicker: true,
                    showCustomUnitForm: $showCustomUnitForm,
                    vm: vm
                )
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(hex: "#F0F0F3"))
            .navigationTitle("Measure Anything")
            .navigationBarTitleDisplayMode(.inline)
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
                        showGlobalSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(hex: "#5F5E5A"))
                    }
                    .buttonStyle(ConverterPressingButtonStyle())
                    .accessibilityLabel("Search")
                    .accessibilityHint("Search all units")

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
        .background(Color.white)
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
                mainTab = .convert
            },
            presentedAsSheet: false
        )
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
}

#Preview {
    let taxonomy = AppTaxonomyStore()
    ConverterView(vm: ConverterViewModel(taxonomy: taxonomy))
        .environmentObject(taxonomy)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
