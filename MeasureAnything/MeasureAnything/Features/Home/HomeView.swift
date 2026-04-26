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

    @State private var showFavorites = false
    @State private var showCustomUnitForm = false
    @State private var scrollToConverterToken = 0
    @State private var homeTab: BottomNav.Tab = .convert
    @State private var exploreResetToken = 0
    @StateObject private var keyboard = KeyboardObserver()
    @State private var factCardSheetItem: FactCardSheetItem?
    @State private var factCardSheetDetent: PresentationDetent = .large

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
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Group {
                    switch homeTab {
                    case .convert:
                        convertTab
                    case .explore:
                        exploreTab
                    case .settings:
                        settingsTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                BottomNav(selected: $homeTab, selectionTint: categoryAccent) { tab in
                    if tab == .explore {
                        exploreResetToken &+= 1
                    }
                }
                // Keep the nav in the hierarchy (avoids toolbar/keyboard transition glitches),
                // but hide it while the keyboard is up so it can't float mid-screen.
                .opacity(keyboard.isVisible ? 0 : 1)
                .allowsHitTesting(!keyboard.isVisible)
            }
            .background(Color(hex: "#F0F0F3"))
            .overlay(alignment: .bottom) {
                if homeTab == .convert && keyboard.isVisible {
                    KeyboardAccessoryBar(
                        accent: categoryAccent,
                        onCancel: cancelConverterKeyboard,
                        onDone: dismissKeyboard
                    )
                    .padding(.bottom, max(0, keyboard.height - proxy.safeAreaInsets.bottom))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: homeTab) { old, new in
                // Ensure keyboard state is fully reset before tab transitions.
                if old == .explore && new != .explore {
                    exploreResetToken &+= 1
                    dismissKeyboard()
                }
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
            .sheet(item: $factCardSheetItem) { item in
                FactCardNavigationShell(
                    initialUnitID: item.unitID,
                    viewModel: vm,
                    dismissEntireFactCardFlow: { factCardSheetItem = nil }
                )
                .presentationDetents([.medium, .large], selection: $factCardSheetDetent)
                .presentationDragIndicator(.visible)
            }
        }
    }

    private struct FactCardSheetItem: Identifiable {
        var id: String { unitID }
        let unitID: String
    }

    private var convertTab: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
                        categoryPillBar

                        ConverterWorkspaceBody(
                            showsCategoryPicker: false,
                            onOpenFactCard: { unitID in
                                factCardSheetItem = FactCardSheetItem(unitID: unitID)
                            },
                            showCustomUnitForm: $showCustomUnitForm,
                            vm: vm
                        )
                        .id(HomeScrollTarget.converter)
                    }
                    .padding(.bottom, ConverterLayout.rhythm24)
                }
                .scrollDismissesKeyboard(.never)
                .onChange(of: scrollToConverterToken) { _, _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(HomeScrollTarget.converter, anchor: .top)
                    }
                }
            }
            .background(Color(hex: "#F0F0F3"))
            .navigationTitle("Measure Anything")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(keyboard.isVisible ? .hidden : .automatic, for: .tabBar)
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

    private var exploreTab: some View {
        ExploreView(vm: vm, selectedTab: $homeTab, resetToken: exploreResetToken)
    }

    private var settingsTab: some View {
        SettingsTabView()
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func cancelConverterKeyboard() {
        vm.restoreInputEditSnapshot()
        dismissKeyboard()
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
    let vm = ConverterViewModel(taxonomy: taxonomy)
    HomeView(vm: vm)
        .environmentObject(taxonomy)
        .environmentObject(vm)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
