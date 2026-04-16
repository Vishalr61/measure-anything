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
    @State private var mainTab: BottomNav.Tab = .convert
    @State private var exploreResetToken = 0

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
                case .explore:
                    ExploreView(vm: vm, selectedTab: $mainTab, resetToken: exploreResetToken)
                case .settings:
                    SettingsTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomNav(selected: $mainTab, selectionTint: categoryAccent) { tab in
                if tab == .explore {
                    exploreResetToken &+= 1
                }
            }
        }
        .background(Color(hex: "#F0F0F3"))
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

                    Button {
                        Haptics.tap()
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
        .background(Color.white)
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
