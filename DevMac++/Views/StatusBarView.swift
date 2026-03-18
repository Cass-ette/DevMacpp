import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            Text("Ready")
                .foregroundColor(Color(hex: "#cccccc"))
                .font(.system(size: 12))
            Spacer()
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(Color(hex: "#007acc"))
    }
}
