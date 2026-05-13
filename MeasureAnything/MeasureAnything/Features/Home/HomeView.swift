import Photos
import StoreKit
import SwiftData
import SwiftUI
import UIKit
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
    @State private var isConverterKeyboardActive: Bool = false
    @State private var scrollToConverterToken = 0
    @State private var homeTab: BottomNav.Tab = .convert
    @State private var exploreResetToken = 0
    @StateObject private var keyboard = KeyboardObserver()
    @State private var factCardSheetItem: FactCardSheetItem?
    @State private var factCardSheetDetent: PresentationDetent = .large
    @State private var isSharePreviewVisible = false

    /// SwiftUI rating-prompt action (iOS 16+). Already used in
    /// `SettingsTabView` for the manual "Rate on App Store" button;
    /// here it's invoked automatically at conversion-count milestones.
    /// iOS rate-limits to 3 prompts per 365 days per user — additional
    /// calls silently no-op, so we don't need our own cooldown.
    @Environment(\.requestReview) private var requestReview
    @AppStorage("lastReviewPromptThreshold") private var lastReviewPromptThreshold: Int = 0

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

    /// Toggles the current FROM→TO pair: removes it if already favourited,
    /// otherwise inserts a new favourite. Both star buttons (nav bar + TO card)
    /// share this so they stay in sync via the live `@Query` favourites array.
    private func toggleCurrentPairFavorite() {
        guard vm.canSaveCurrentPairAsFavorite else { return }
        if let existing = favorites.first(where: {
            $0.categoryRaw == vm.selectedCategory.rawValue
                && $0.fromUnitID == vm.selectedFromUnitID
                && $0.toUnitID == vm.selectedToUnitID
        }) {
            modelContext.delete(existing)
        } else {
            let fav = FavoriteConversion(
                categoryRaw: vm.selectedCategory.rawValue,
                fromUnitID: vm.selectedFromUnitID,
                toUnitID: vm.selectedToUnitID
            )
            modelContext.insert(fav)
            Haptics.favorite()
        }
        try? modelContext.save()
    }

    private func focusConverterFromAbsurdShortcut() {
        scrollToConverterToken &+= 1
    }

    /// Fires `requestReview()` when the user crosses a conversion-count
    /// milestone (10, 50, 150). Each tier is gated by `@AppStorage` so a
    /// rapid burst of conversions (e.g. spam-tapping the dice card) only
    /// triggers one prompt per tier. iOS itself caps to 3 prompts/365d.
    private func checkAndRequestReviewIfNeeded() {
        let count = ConversionHistory.shared.totalRecordedConversions
        let thresholds = [10, 50, 150]

        guard let nextThreshold = thresholds.first(where: { $0 > lastReviewPromptThreshold }) else { return }
        guard count >= nextThreshold else { return }

        // Bump the stored threshold first so a rapid follow-up call
        // (e.g. another conversion in the same frame) can't double-fire.
        lastReviewPromptThreshold = nextThreshold

        // Slight delay so the prompt doesn't slam onto a roll-landing
        // animation or result transition.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            requestReview()
        }
    }

    var body: some View {
        ZStack {
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
                // but collapse its height while the keyboard is up so it doesn't reserve a
                // chrome strip above the keyboard. NOTE: no `.clipped()` — that would also
                // clip the nav's white background's extension into the bottom safe area,
                // exposing chrome grey on devices with a home indicator.
                .frame(height: keyboard.isVisible ? 0 : nil)
                .opacity(keyboard.isVisible ? 0 : 1)
                .allowsHitTesting(!keyboard.isVisible)
            }

            if isSharePreviewVisible {
                sharePreviewOverlay
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSharePreviewVisible)
        .background(homeRootBackground)
        .onChange(of: homeTab) { old, new in
            // Light haptic on every tab switch.
            if old != new {
                Haptics.tap()
            }
            // Ensure keyboard state is fully reset before tab transitions.
            if old == .explore && new != .explore {
                exploreResetToken &+= 1
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        }
        // Each successful conversion result feeds the review-prompt
        // milestone gate. Only successful (non-nil) results — empty/invalid
        // input is a no-op.
        .onChange(of: vm.conversionResult) { _, newResult in
            guard newResult != nil else { return }
            checkAndRequestReviewIfNeeded()
        }
        .sheet(isPresented: $showFavorites) {
            FavoritesListView(registry: vm.currentRegistry, accent: categoryAccent) { fav in
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

    private struct FactCardSheetItem: Identifiable {
        var id: String { unitID }
        let unitID: String
    }

    private var convertTab: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
                        if !isConverterKeyboardActive {
                            categoryPillBar
                        }

                        ConverterWorkspaceBody(
                            showsCategoryPicker: false,
                            onOpenFactCard: { unitID in
                                factCardSheetItem = FactCardSheetItem(unitID: unitID)
                            },
                            onShareTapped: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSharePreviewVisible = true
                                }
                            },
                            showCustomUnitForm: $showCustomUnitForm,
                            isKeyboardActive: $isConverterKeyboardActive,
                            vm: vm
                        )
                        .id(HomeScrollTarget.converter)
                    }
                    .padding(.bottom, isConverterKeyboardActive ? 120 : ConverterLayout.rhythm24)
                }
                .background(convertTabChromeBackground)
                .scrollDismissesKeyboard(.never)
                .onChange(of: scrollToConverterToken) { _, _ in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(HomeScrollTarget.converter, anchor: .top)
                    }
                }
            }
            .background(convertTabChromeBackground)
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isConverterKeyboardActive {
                        // Cancel — revert and dismiss
                        Button {
                            vm.restoreInputEditSnapshot()
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(ConverterPressingButtonStyle())

                        // Done — confirm and dismiss
                        Button {
                            UIApplication.shared.sendAction(
                                #selector(UIResponder.resignFirstResponder),
                                to: nil, from: nil, for: nil
                            )
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(categoryAccent)
                        }
                        .buttonStyle(ConverterPressingButtonStyle())
                    } else {
                        // Star toggles favourite state — adds when not favourited, removes when already favourited.
                        Button {
                            toggleCurrentPairFavorite()
                        } label: {
                            Image(systemName: isCurrentPairAlreadyFavorite ? "star.fill" : "star")
                                .font(.body.weight(.regular))
                                .imageScale(.medium)
                                .foregroundStyle(isCurrentPairAlreadyFavorite ? categoryAccent : Color.primary)
                        }
                        .disabled(!vm.canSaveCurrentPairAsFavorite)
                        .buttonStyle(ConverterPressingButtonStyle())
                        .accessibilityLabel(isCurrentPairAlreadyFavorite ? "Remove from favorites" : "Save as favorite")

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
            .animation(.easeInOut(duration: 0.15), value: isConverterKeyboardActive)
        }
        .background(convertTabChromeBackground)
    }

    private var homeRootBackground: Color {
        Color(hex: "#F0F0F3")
    }

    private var convertTabChromeBackground: Color {
        Color(hex: "#F0F0F3")
    }

    // MARK: – Share preview overlay + image generation

    @ViewBuilder
    private var sharePreviewOverlay: some View {
        if let r = vm.conversionResult,
           let fromName = vm.fromUnit?.name,
           let toName = vm.toUnit?.name {
            let fromVal = vm.formatNumberForDisplay(r.inputValue)
            let toVal = ShareCardView.formatForCard(vm.formatNumberForDisplay(r.outputValue))
            SharePreviewOverlay(
                fromValue: fromVal,
                fromUnit: fromName,
                toValue: toVal,
                toUnit: toName,
                category: shareCategoryTag(for: vm.selectedCategory),
                isPrecisionMode: vm.precisionModeEnabled,
                accentColor: categoryAccent,
                onDismiss: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSharePreviewVisible = false
                    }
                },
                onShare: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSharePreviewVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        presentShareSheet()
                    }
                },
                onSave: {
                    saveCardToPhotos()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSharePreviewVisible = false
                    }
                }
            )
        }
    }

    private func shareCategoryTag(for category: UnitCategory) -> String {
        switch category {
        case .length:      return "LENGTH"
        case .mass:        return "MASS"
        case .time:        return "TIME"
        case .temperature: return "TEMP"
        case .volume:      return "VOLUME"
        }
    }

    @MainActor
    private func renderCardImage() -> UIImage? {
        guard #available(iOS 16.0, *) else { return nil }
        guard let r = vm.conversionResult,
              let fromName = vm.fromUnit?.name,
              let toName = vm.toUnit?.name else { return nil }

        let fromVal = vm.formatNumberForDisplay(r.inputValue)
        let toVal = ShareCardView.formatForCard(vm.formatNumberForDisplay(r.outputValue))

        let card = ShareCardView(
            fromValue: fromVal,
            fromUnit: fromName,
            toValue: toVal,
            toUnit: toName,
            category: shareCategoryTag(for: vm.selectedCategory),
            isPrecisionMode: vm.precisionModeEnabled
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        renderer.proposedSize = ProposedViewSize(
            width: ShareCardView.cardWidth,
            height: ShareCardView.cardHeight
        )
        return renderer.uiImage
    }

    private func presentShareSheet() {
        guard let image = renderCardImage() else { return }
        guard let topVC = topMostViewController() else { return }

        let vc = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        if let popover = vc.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }
        topVC.present(vc, animated: true)
    }

    private func saveCardToPhotos() {
        guard let image = renderCardImage() else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
    }

    private func topMostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController
                ?? scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private var exploreTab: some View {
        ExploreView(vm: vm, selectedTab: $homeTab, resetToken: exploreResetToken)
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
    let vm = ConverterViewModel(taxonomy: taxonomy)
    HomeView(vm: vm)
        .environmentObject(taxonomy)
        .environmentObject(vm)
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self], inMemory: true)
}
