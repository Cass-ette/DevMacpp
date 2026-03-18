import SwiftUI

struct BottomPanelView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            Text("Bottom Panel")
                .foregroundColor(Color(hex: "#cccccc"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#252526"))
    }
}
