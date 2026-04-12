import SwiftUI

struct DiceRollCard: View {
    @ObservedObject var vm: ConverterViewModel
    var accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            leftColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            rightColumn
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            vm.rollDice()
        }
        .onLongPressGesture(minimumDuration: 0.20) {
            vm.rollDiceDual()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Roll the dice")
        .accessibilityHint("Tap to randomise the target unit. Long press briefly to randomise both units.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Randomise both units")) {
            vm.rollDiceDual()
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Roll the\ndice")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)

            subtitleRow
        }
    }

    private var subtitleRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Group {
                if vm.diceSubtitleIsDualFormat {
                    Text(vm.diceLandedUnitName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    HStack(spacing: 0) {
                        Text("landed on ")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.78))

                        Text(vm.diceLandedUnitName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            if vm.showDiceSubtitle, vm.showDiceLongPressHint {
                Text("hold for full chaos")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .accessibilityHidden(true)
            }
        }
        .opacity(vm.showDiceSubtitle ? 1 : 0)
        .frame(minHeight: 14, alignment: .leading)
        .animation(.easeIn(duration: 0.25), value: vm.showDiceSubtitle)
        .animation(.easeOut(duration: 0.25), value: vm.showDiceLongPressHint)
    }

    private var rightColumn: some View {
        DiceFaceView(face: $vm.diceDisplayFace, pipColor: accent)
            .rotationEffect(.degrees(vm.diceRotationDegrees))
    }

    private var cardBackground: some View {
        ZStack(alignment: .topTrailing) {
            accent

            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 14)
                .frame(width: 90, height: 90)
                .offset(x: 30, y: -30)
        }
    }
}

