import SwiftUI
import MeasureAnythingCore

struct ExploreView: View {
    @ObservedObject var vm: ConverterViewModel
    @Binding var selectedTab: BottomNav.Tab
    var resetToken: Int = 0

    var body: some View {
        NavigationStack {
            GlobalUnitSearchBody(
                vm: vm,
                onUnitSelected: {
                    selectedTab = .convert
                },
                resetToken: resetToken,
                isExploreTab: true
            )
        }
    }
}
