import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState

    var fileSizeString: String {
        let bytes = appState.fileSize
        if bytes < 1024 {
            return "\(bytes) B"
        } else {
            let kb = Double(bytes) / 1024.0
            return String(format: "%.1f KB", kb)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Text("第 \(appState.cursorPosition.line) 行，第 \(appState.cursorPosition.column) 列")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#cccccc"))

            Divider()
                .frame(height: 12)
                .background(Color(hex: "#3e3e42"))

            Text(appState.insertMode.rawValue)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#cccccc"))

            Divider()
                .frame(height: 12)
                .background(Color(hex: "#3e3e42"))

            Text(fileSizeString)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#cccccc"))

            Divider()
                .frame(height: 12)
                .background(Color(hex: "#3e3e42"))

            Text("C++")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#cccccc"))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(Color(hex: "#007acc").opacity(0.15))
    }
}
