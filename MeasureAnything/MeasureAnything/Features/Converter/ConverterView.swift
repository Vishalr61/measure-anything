import SwiftUI
import MeasureAnythingCore

struct ConverterView: View {
    @StateObject private var vm = ConverterViewModel()
    @FocusState private var valueFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    inputs
                    resultCard
                }
                .padding()
            }
            .navigationTitle("Measure Anything")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Category", selection: $vm.selectedCategory) {
                ForEach(vm.categories, id: \.self) { category in
                    Text(category.rawValue.capitalized).tag(category)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Picker("Mode", selection: $vm.selectedMode) {
                    ForEach(vm.modes, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Explain like a meme", isOn: $vm.isMemeExplanationEnabled)
            }
        }
    }

    private var inputs: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amount")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("e.g. 10 or 3.5", text: $vm.inputText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)
                .focused($valueFieldFocused)
                .font(.body.monospacedDigit())
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            valueFieldFocused = false
                        }
                        .fontWeight(.semibold)
                    }
                }

            HStack(alignment: .top, spacing: 12) {
                unitPickerColumn(title: "From", selection: $vm.selectedFromUnitID)
                swapButton
                unitPickerColumn(title: "To", selection: $vm.selectedToUnitID)
            }
        }
    }

    private var swapButton: some View {
        Button(action: { vm.swapUnits() }) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Swap from and to units")
        .padding(.top, 22)
    }

    private func unitPickerColumn(title: String, selection: Binding<UnitDefinition.ID>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(vm.availableUnits, id: \.id) { unit in
                    Text(unit.name).tag(unit.id)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Result")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            if let err = vm.validationError {
                Text(err)
                    .font(.body)
                    .foregroundStyle(.red)
            } else if let result = vm.conversionResult,
                      let fromName = vm.fromUnit?.name,
                      let toName = vm.toUnit?.name {
                let input = vm.formatNumberForDisplay(result.inputValue)
                let output = vm.formatNumberForDisplay(result.outputValue)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(input) \(fromName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                    Text("\(output) \(toName)")
                        .font(.title2.weight(.semibold))
                }

                if let meme = result.memeExplanation, !meme.isEmpty {
                    Divider()
                    Text(meme)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Choose units and enter a value.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    ConverterView()
}
