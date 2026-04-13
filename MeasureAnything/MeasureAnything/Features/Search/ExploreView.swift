import SwiftUI
import MeasureAnythingCore

struct ExploreView: View {
    @ObservedObject var vm: ConverterViewModel
    @Binding var selectedTab: BottomNav.Tab

    var body: some View {
        NavigationStack {
            GlobalUnitSearchBody(vm: vm) {
                selectedTab = .convert
            }
        }
    }
}
