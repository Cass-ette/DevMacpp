import SwiftUI

struct TemplatePickerView: View {
    @EnvironmentObject var templateService: TemplateService
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var showSaveSheet = false
    @State private var newName = ""
    @State private var newDesc = ""

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
                        HStack(spacing: 0) {
                            Button {
                                applyTemplate(template)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(template.name)
                                                .font(.system(size: 13))
                                                .foregroundColor(.white)
                                            if template.isBuiltIn {
                                                Text("内置")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(Color(hex: "#858585"))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 3)
                                                            .strokeBorder(Color(hex: "#555555"), lineWidth: 0.5)
                                                    )
                                            }
                                        }
                                        if !template.description.isEmpty {
                                            Text(template.description)
                                                .font(.system(size: 11))
                                                .foregroundColor(Color(hex: "#858585"))
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#555555"))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if !template.isBuiltIn {
                                Button {
                                    templateService.removeTemplate(id: template.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color(hex: "#858585"))
                                        .frame(width: 28, height: 28)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 8)
                            }
                        }
                        .background(Color(hex: "#2d2d30"))
                        .cornerRadius(4)
                    }
                }
                .padding(8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#1e1e1e"))

            Divider().background(Color(hex: "#3e3e42"))

            Button {
                newName = ""
                newDesc = ""
                showSaveSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                    Text("将当前代码保存为模板...")
                        .font(.system(size: 12))
                }
                .foregroundColor(Color(hex: "#4caf50"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .background(Color(hex: "#252526"))
        }
        .frame(width: 340, height: 420)
        .background(Color(hex: "#252526"))
        .sheet(isPresented: $showSaveSheet) {
            SaveTemplateSheet(name: $newName, desc: $newDesc) {
                templateService.addTemplate(
                    name: newName.trimmingCharacters(in: .whitespaces),
                    content: appState.fileContent,
                    description: newDesc.trimmingCharacters(in: .whitespaces)
                )
            }
        }
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

struct SaveTemplateSheet: View {
    @Binding var name: String
    @Binding var desc: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("保存为模板")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("模板名称")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#858585"))
                TextField("例：线段树模板", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color(hex: "#3c3c3c"))
                    .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("描述（可选）")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#858585"))
                TextField("简短描述", text: $desc)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color(hex: "#3c3c3c"))
                    .cornerRadius(4)
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#cccccc"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#3c3c3c"))
                    .cornerRadius(4)

                Button("保存") {
                    onSave()
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(canSave ? .white : Color(hex: "#555555"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(canSave ? Color(hex: "#007acc") : Color(hex: "#3c3c3c"))
                .cornerRadius(4)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 300)
        .background(Color(hex: "#252526"))
        .preferredColorScheme(.dark)
    }
}
