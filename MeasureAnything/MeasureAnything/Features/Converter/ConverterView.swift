import SwiftUI
import MeasureAnythingCore

struct ConverterView: View {
    @StateObject private var vm = ConverterViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                header
                inputs
                resultCard
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Measure Anything")
            .navigationBarTitleDisplayMode(.inline)
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

            HStack(spacing: 12) {
                Picker("Mode", selection: $vm.selectedMode) {
                    ForEach(vm.modes, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Explain like a meme", isOn: $vm.isMemeExplanationEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Explain like a meme")
            }

            HStack {
                Text("Explain like a meme")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(vm.isMemeExplanationEnabled ? "On" : "Off")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inputs: some View {
        VStack(spacing: 12) {
            TextField("Value", text: $vm.inputText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.decimalPad)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("From unit", selection: $vm.selectedFromUnitID) {
                        ForEach(vm.availableUnits, id: \.id) { unit in
                            Text(unit.name).tag(unit.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: { vm.swapUnits() }) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityLabel("Swap units")

                VStack(alignment: .leading, spacing: 6) {
                    Text("To")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("To unit", selection: $vm.selectedToUnitID) {
                        ForEach(vm.availableUnits, id: \.id) { unit in
                            Text(unit.name).tag(unit.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let err = vm.validationError {
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if let result = vm.conversionResult,
                      let fromName = vm.fromUnit?.name,
                      let toName = vm.toUnit?.name {
                let input = vm.formatNumber(result.inputValue)
                let output = vm.formatNumber(result.outputValue)

                Text("\(input) \(fromName) = \(output) \(toName)")
                    .font(.title3.weight(.semibold))
                    .lineLimit(3)

                if let meme = result.memeExplanation, !meme.isEmpty {
                    Text(meme)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Pick units to convert.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    ConverterView()
}
