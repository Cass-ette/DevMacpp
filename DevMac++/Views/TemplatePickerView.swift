import SwiftUI

struct TemplatePickerView: View {
    @EnvironmentObject var templateService: TemplateService
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("选择模板")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

            Divider().background(Color(hex: "#3e3e42"))

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(templateService.templates) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(template.name)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                    Text(template.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#858585"))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#858585"))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#2d2d30"))
                        }
                        .buttonStyle(.plain)
                        .cornerRadius(4)
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#1e1e1e"))
        }
        .frame(width: 320, height: 380)
        .background(Color(hex: "#252526"))
    }

    private func applyTemplate(_ template: CodeTemplate) {
        appState.fileContent = template.content
        appState.currentFileName = "未保存.cpp"
        appState.currentFilePath = nil
        appState.isModified = true
        appState.fileSize = template.content.utf8.count
        dismiss()
    }
}
