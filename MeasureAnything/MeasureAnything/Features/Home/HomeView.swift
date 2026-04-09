import SwiftUI
import MeasureAnythingCore

/// Discovery dashboard: cards and search entry; pushes shared `ConverterView` without changing converter behavior.
struct HomeView: View {
    @ObservedObject var vm: ConverterViewModel
    @EnvironmentObject private var taxonomyStore: AppTaxonomyStore

    @State private var path = NavigationPath()
    @State private var showTaxonomySearch = false
    @State private var showFavorites = false

    private enum HomeNav: Hashable {
        case converter
    }

    /// Single converter destination on the root stack (avoids duplicate pushes and works with `navigationDestination`).
    private func pushConverter() {
        path = NavigationPath()
        path.append(HomeNav.converter)
    }

    /// Prefer normal conversions when entering from a category tile.
    private func selectDefaultNormalMode() {
        if vm.modes.contains(.normal) {
            vm.selectedMode = .normal
        } else if let first = vm.modes.first {
            vm.selectedMode = first
        }
    }

    /// Keep absurd mode on a valid taxonomy category.
    private func ensureSelectedCategoryIsValid() {
        if !vm.categories.contains(vm.selectedCategory), let first = vm.categories.first {
            vm.selectedCategory = first
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: ConverterLayout.rhythm16) {
                    dashboardHeader

                    searchBarButton
                        .padding(.top, ConverterLayout.rhythm8)

                    continueConverterCard
                        .padding(.top, ConverterLayout.rhythm12)

                    recommendedSection

                    categoryGridSection
                }
                .padding(.horizontal, ConverterLayout.horizontalInset)
                .padding(.bottom, ConverterLayout.rhythm24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Measure Anything")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "ruler")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(ConverterCategoryAccent.accent(for: .length))
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: ConverterLayout.rhythm12) {
                        Button {
                            Haptics.tap()
                            showFavorites = true
                        } label: {
                            Image(systemName: "list.star")
                                .font(.body.weight(.regular))
                                .imageScale(.medium)
                        }
                        .accessibilityLabel("View favorites")

                        Button {
                            Haptics.tap()
                            showTaxonomySearch = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.body.weight(.regular))
                                .imageScale(.medium)
                        }
                        .accessibilityLabel("Search taxonomy")
                    }
                }
            }
            .navigationDestination(for: HomeNav.self) { _ in
                ConverterView(embedsInParentNavigationStack: true, vm: vm)
                    .environmentObject(taxonomyStore)
            }
            .sheet(isPresented: $showTaxonomySearch) {
                TaxonomySearchView { itemId in
                    if let route = taxonomyStore.converterRoute(forTaxonomyItemId: itemId) {
                        vm.applyTaxonomyRoute(route)
                        pushConverter()
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
                    pushConverter()
                }
            }
        }
    }

    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: ConverterLayout.rhythm12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Convert anything")
                    .font(.title2.weight(.bold))
                Text("Pick a category or try an absurd comparison.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
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

    private var continueConverterCard: some View {
        let accent = ConverterCategoryAccent.accent(for: vm.selectedCategory)
        return Button {
            Haptics.tap()
            pushConverter()
        } label: {
            HStack(alignment: .center, spacing: ConverterLayout.rhythm16) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue converting")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Open the full converter with your current category and units.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(ConverterLayout.rhythm16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ConverterLayout.cardCornerRadius, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ConverterLayout.cardCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(ConverterLayout.strokeOpacitySubtle), lineWidth: ConverterLayout.strokeHairline)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue converting")
        .accessibilityHint("Opens the converter with your current settings")
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
            HStack {
                Text("Recommended")
                    .font(.title3.weight(.bold))
                Spacer()
            }

            Button {
                Haptics.tap()
                ensureSelectedCategoryIsValid()
                vm.selectedMode = .absurd
                pushConverter()
            } label: {
                featuredAbsurdCard
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Absurd conversions")
            .accessibilityHint("Opens converter in absurd mode")
        }
    }

    private var featuredAbsurdCard: some View {
        let g = LinearGradient(
            colors: [
                ConverterCategoryAccent.accent(for: .length),
                ConverterCategoryAccent.accent(for: .volume).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return HStack(alignment: .top, spacing: ConverterLayout.rhythm16) {
            VStack(alignment: .leading, spacing: ConverterLayout.rhythm8) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
                Text("Absurd conversions")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("Fun comparisons backed by real factors")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(ConverterLayout.rhythm20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ConverterLayout.cardCornerRadius, style: .continuous)
                .fill(g)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ConverterLayout.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: ConverterLayout.strokeHairline)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }

    private var categoryGridSection: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
            Text("Categories")
                .font(.title3.weight(.bold))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: ConverterLayout.rhythm12),
                    GridItem(.flexible(), spacing: ConverterLayout.rhythm12)
                ],
                spacing: ConverterLayout.rhythm12
            ) {
                ForEach(vm.categories, id: \.self) { category in
                    Button {
                        Haptics.tap()
                        vm.selectedCategory = category
                        selectDefaultNormalMode()
                        pushConverter()
                    } label: {
                        categoryCard(for: category)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(taxonomyStore.categoryDisplay(for: category).displayName) category")
                    .accessibilityHint("Opens converter for this category")
                }
            }
        }
    }

    private func categoryCard(for category: UnitCategory) -> some View {
        let display = taxonomyStore.categoryDisplay(for: category)
        let accent = ConverterCategoryAccent.accent(for: category)
        return VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: categoryIconName(category))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
            }
            Text(display.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            if let d = display.description, !d.isEmpty {
                Text(d)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(categoryFallbackDescriptor(category))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(ConverterLayout.rhythm16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(ConverterLayout.strokeOpacitySubtle), lineWidth: ConverterLayout.strokeHairline)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private func categoryIconName(_ category: UnitCategory) -> String {
        switch category {
        case .length: "ruler"
        case .mass: "scalemass"
        case .time: "clock"
        case .temperature: "thermometer.medium"
        case .volume: "cube.fill"
        }
    }

    private func categoryFallbackDescriptor(_ category: UnitCategory) -> String {
        switch category {
        case .length: "Distance and height"
        case .mass: "Weight and mass"
        case .time: "Durations and rates"
        case .temperature: "Degrees and scales"
        case .volume: "Space and capacity"
        }
    }
}

#Preview {
    let taxonomy = AppTaxonomyStore()
    HomeView(vm: ConverterViewModel(taxonomy: taxonomy))
        .environmentObject(taxonomy)
}
