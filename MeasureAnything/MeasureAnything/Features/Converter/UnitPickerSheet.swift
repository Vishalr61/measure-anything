import SwiftUI
import MeasureAnythingCore

struct UnitPickerSheet: View {
    let units: [UnitDefinition]
    let selectedID: UnitDefinition.ID
    let accent: Color
    let onSelect: (UnitDefinition.ID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var normalUnits: [UnitDefinition] {
        units.filter { $0.kind == .normal }
    }

    private var absurdUnits: [UnitDefinition] {
        units.filter { $0.kind != .normal }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var filteredUnits: [UnitDefinition] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        return units.filter { $0.name.lowercased().contains(query) }
    }

    private var groupedAbsurd: [(title: String, units: [UnitDefinition])] {
        UnitScaleGroups.grouped(absurdUnits)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                unitList
            }
            .navigationTitle("Choose unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hex: "#B4B2A9"))
                .font(.system(size: 15))
            TextField("Search units…", text: $searchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(hex: "#B4B2A9"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "#F0F0F3"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var unitList: some View {
        List {
            if isSearching {
                if filteredUnits.isEmpty {
                    Text("No units match \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredUnits, id: \.id) { unit in
                        unitRow(unit)
                    }
                }
            } else {
                if !normalUnits.isEmpty {
                    Section {
                        ForEach(normalUnits, id: \.id) { unit in
                            unitRow(unit)
                        }
                    } header: {
                        sectionHeader("Standard")
                    }
                }

                if !absurdUnits.isEmpty {
                    ForEach(groupedAbsurd, id: \.title) { group in
                        Section {
                            ForEach(group.units, id: \.id) { unit in
                                unitRow(unit)
                            }
                        } header: {
                            sectionHeader(group.title)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func unitRow(_ unit: UnitDefinition) -> some View {
        Button {
            Haptics.tap()
            onSelect(unit.id)
            dismiss()
        } label: {
            HStack {
                Text(unit.name)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                Spacer()
                if unit.id == selectedID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .listRowBackground(unit.id == selectedID ? accent.opacity(0.06) : Color.clear)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(hex: "#888780"))
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.top, 4)
    }
}
