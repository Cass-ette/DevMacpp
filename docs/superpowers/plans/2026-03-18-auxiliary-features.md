# 辅助功能实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现代码模板、查找替换、帮助文档三个辅助功能，完善 IDE 使用体验

**Architecture:**
- 模板：JSON 文件存储在 `~/Library/Application Support/DevMac++/templates.json`
- 查找：Monaco Editor 内置查找 API，集成到编辑器顶部
- 帮助：本地 HTML 文件通过 WKWebView 在独立窗口显示

**Tech Stack:** SwiftUI, WKWebView, Monaco Editor API, FileManager

---

## Chunk 1: 查找替换

### Task 1: Monaco 查找替换集成

**Files:**
- Modify: `DevMac++/Resources/monaco/editor.html`
- Modify: `DevMac++/Views/MonacoEditorView.swift`

- [ ] **Step 1: 添加查找替换 CSS 到 editor.html**

在 `<style>` 中添加：

```css
.find-widget {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    z-index: 100;
    background: #2d2d30;
    border-bottom: 1px solid #3e3e42;
    padding: 8px 12px;
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
}
.find-input {
    background: #3c3c3c;
    border: 1px solid #3e3e42;
    color: #cccccc;
    padding: 4px 8px;
    border-radius: 3px;
    font-family: 'Monaco', monospace;
    font-size: 12px;
    width: 200px;
}
.find-input:focus {
    outline: none;
    border-color: #007acc;
}
.find-btn {
    background: none;
    border: 1px solid #3e3e42;
    color: #cccccc;
    padding: 4px 8px;
    border-radius: 3px;
    cursor: pointer;
    font-size: 12px;
}
.find-btn:hover {
    background: #3e3e42;
}
.find-count {
    color: #858585;
    font-size: 11px;
    min-width: 60px;
}
.find-close {
    margin-left: auto;
    background: none;
    border: none;
    color: #858585;
    cursor: pointer;
    font-size: 16px;
}
```

- [ ] **Step 2: 添加查找替换 HTML 控件到 editor.html body**

在 `<body>` 的 `<div id="container">` 后面添加：

```html
<div id="find-widget" class="find-widget" style="display: none;">
    <input type="text" id="find-input" class="find-input" placeholder="查找...">
    <input type="text" id="replace-input" class="find-input" placeholder="替换..." style="width: 160px;">
    <button id="find-prev" class="find-btn">↑</button>
    <button id="find-next" class="find-btn">↓</button>
    <button id="replace-btn" class="find-btn">替换</button>
    <button id="replace-all-btn" class="find-btn">全部替换</button>
    <span id="find-count" class="find-count"></span>
    <button id="find-close" class="find-close">&times;</button>
</div>
```

- [ ] **Step 3: 添加查找替换 JS 逻辑到 editor.html**

在 `require(['vs/editor/editor.main'], function () {` 块内部，`window.editor.onDidChangeModelContent` 之后添加：

```javascript
// 查找替换控件
const findWidget = document.getElementById('find-widget');
const findInput = document.getElementById('find-input');
const replaceInput = document.getElementById('replace-input');
const findCount = document.getElementById('find-count');

let currentMatch = 0;
let totalMatches = 0;

document.getElementById('find-prev').addEventListener('click', findPrev);
document.getElementById('find-next').addEventListener('click', findNext);
document.getElementById('replace-btn').addEventListener('click', replaceOne);
document.getElementById('replace-all-btn').addEventListener('click', replaceAll);
document.getElementById('find-close').addEventListener('click', closeFindWidget);
findInput.addEventListener('input', doFind);
findInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.shiftKey ? findPrev() : findNext(); }
});
document.addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === 'f') {
        e.preventDefault();
        openFindWidget();
    }
    if (e.key === 'Escape' && findWidget.style.display !== 'none') {
        closeFindWidget();
    }
});

function openFindWidget() {
    findWidget.style.display = 'flex';
    findInput.focus();
    findInput.select();
}

function closeFindWidget() {
    findWidget.style.display = 'none';
    findInput.value = '';
    replaceInput.value = '';
    findCount.textContent = '';
    window.editor.getModel().setMarkers([]);
}

function doFind() {
    const searchString = findInput.value;
    if (!searchString) {
        findCount.textContent = '';
        window.editor.getModel().setMarkers([]);
        return;
    }
    const model = window.editor.getModel();
    const matches = model.findMatches(searchString, false, false, false, null, true);
    totalMatches = matches.length;
    currentMatch = matches.length > 0 ? 1 : 0;
    findCount.textContent = totalMatches > 0 ? `1 / ${totalMatches}` : '无匹配';

    // 高亮所有匹配
    const decorations = matches.map(m => ({
        range: m.range,
        options: { className: 'find-match', overviewRuler: { color: 'rgba(255,200,0,0.5)', position: 1 } }
    }));
    window.editor.deltaDecorations(
        window.findDecorations || [],
        decorations
    );
    window.findDecorations = window.editor.getModel().deltaDecorations(window.findDecorations || [], decorations);

    if (matches.length > 0) {
        window.editor.revealLineInCenter(matches[0].range.startLineNumber);
        window.editor.setPosition({ lineNumber: matches[0].range.startLineNumber, column: matches[0].range.startColumn });
    }
}

function findNext() {
    const matches = window.editor.getModel().findMatches(findInput.value, false, false, false, null, true);
    if (matches.length === 0) return;
    currentMatch = (currentMatch % matches.length) + 1;
    const match = matches[currentMatch - 1];
    window.editor.revealLineInCenter(match.range.startLineNumber);
    window.editor.setPosition({ lineNumber: match.range.startLineNumber, column: match.range.startColumn });
    findCount.textContent = `${currentMatch} / ${matches.length}`;
}

function findPrev() {
    const matches = window.editor.getModel().findMatches(findInput.value, false, false, false, null, true);
    if (matches.length === 0) return;
    currentMatch = currentMatch > 1 ? currentMatch - 1 : matches.length;
    const match = matches[currentMatch - 1];
    window.editor.revealLineInCenter(match.range.startLineNumber);
    window.editor.setPosition({ lineNumber: match.range.startLineNumber, column: match.range.startColumn });
    findCount.textContent = `${currentMatch} / ${matches.length}`;
}

function replaceOne() {
    const searchString = findInput.value;
    const replaceString = replaceInput.value;
    if (!searchString) return;
    const position = window.editor.getPosition();
    const model = window.editor.getModel();
    const matches = model.findMatches(searchString, false, false, false, null, true);
    for (const match of matches) {
        if (match.range.startLineNumber === position.lineNumber &&
            match.range.startColumn === position.column) {
            model.pushEditOperations([], [{
                range: match.range,
                text: replaceString
            }]);
            break;
        }
    }
    doFind();
}

function replaceAll() {
    const searchString = findInput.value;
    const replaceString = replaceInput.value;
    if (!searchString) return;
    const model = window.editor.getModel();
    const matches = model.findMatches(searchString, false, false, false, null, true);
    model.pushEditOperations([], matches.map(match => ({
        range: match.range,
        text: replaceString
    })));
    doFind();
}
```

- [ ] **Step 4: 添加查找匹配高亮样式**

在 `<style>` 中添加：

```css
.find-match {
    background: rgba(255, 200, 0, 0.3);
}
```

- [ ] **Step 5: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add find/replace in Monaco Editor (Cmd+F)"
```

---

## Chunk 2: 代码模板

### Task 2: 模板系统

**Files:**
- Create: `DevMac++/Models/Template.swift`
- Create: `DevMac++/Services/TemplateService.swift`
- Modify: `DevMac++/Views/SidebarView.swift` (new file button)
- Modify: `DevMac++/App/DevMacApp.swift`

- [ ] **Step 1: 创建 Template.swift**

```swift
import Foundation

struct CodeTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String
    var description: String
    var createdAt: Date

    init(name: String, content: String, description: String = "") {
        self.id = UUID()
        self.name = name
        self.content = content
        self.description = description
        self.createdAt = Date()
    }
}

struct TemplateCategory: Identifiable {
    let id = UUID()
    var name: String
    var templates: [CodeTemplate]
}
```

- [ ] **Step 2: 创建 TemplateService.swift**

```swift
import Foundation
import SwiftUI

class TemplateService: ObservableObject {
    @Published var templates: [CodeTemplate] = []
    @Published var selectedTemplate: CodeTemplate?

    private let templatesURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let devmacDir = appSupport.appendingPathComponent("DevMac++", isDirectory: true)
        try? FileManager.default.createDirectory(at: devmacDir, withIntermediateDirectories: true)
        templatesURL = devmacDir.appendingPathComponent("templates.json")

        loadTemplates()
    }

    func loadTemplates() {
        // 默认空白模板
        let defaultTemplates = [
            CodeTemplate(
                name: "空白文件",
                content: "#include <bits/stdc++.h>\nusing namespace std;\n\nint main() {\n    \n    return 0;\n}\n",
                description: "标准空白 C++ 文件"
            )
        ]

        guard FileManager.default.fileExists(atPath: templatesURL.path) else {
            templates = defaultTemplates
            saveTemplates()
            return
        }

        do {
            let data = try Data(contentsOf: templatesURL)
            templates = try JSONDecoder().decode([CodeTemplate].self, from: data)
        } catch {
            templates = defaultTemplates
        }
    }

    func saveTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: templatesURL)
        } catch {
            print("Failed to save templates: \(error)")
        }
    }

    func addTemplate(name: String, content: String, description: String = "") {
        let template = CodeTemplate(name: name, content: content, description: description)
        templates.append(template)
        saveTemplates()
    }

    func removeTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        saveTemplates()
    }

    func updateTemplate(_ template: CodeTemplate) {
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
            saveTemplates()
        }
    }
}
```

- [ ] **Step 3: 注册到 DevMacApp.swift**

```swift
@StateObject private var templateService = TemplateService()
```

添加到 ContentView:
```swift
.environmentObject(templateService)
```

- [ ] **Step 4: 创建模板选择视图**

创建 `DevMac++/Views/TemplatePickerView.swift`：

```swift
import SwiftUI

struct TemplatePickerView: View {
    @EnvironmentObject var templateService: TemplateService
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("选择模板")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(templateService.templates) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                    Text(template.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#2d2d30"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 300, height: 350)
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
```

- [ ] **Step 5: 更新新建文件逻辑**

修改 ToolbarView 或 AppMenuCommands 的新建文件操作，使其打开模板选择面板：

```swift
@State private var showTemplatePicker = false

// 新建按钮 action
Button {
    showTemplatePicker = true
} icon: "doc"
```

添加 Sheet:
```swift
.sheet(isPresented: $showTemplatePicker) {
    TemplatePickerView()
}
```

- [ ] **Step 6: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add code template system with blank template"
```

---

## Chunk 3: 帮助文档

### Task 3: 帮助文档系统

**Files:**
- Create: `DevMac++/Views/HelpWindow.swift`
- Create: `DevMac++/Resources/help/index.html`
- Modify: `DevMac++/Views/AppMenuCommands.swift`

- [ ] **Step 1: 创建帮助窗口 HelpWindow.swift**

```swift
import SwiftUI
import WebKit

struct HelpWindow: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let content: String

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#2d2d30"))

            Divider()

            ScrollView {
                Text(content)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: "#cccccc"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#1e1e1e"))
        }
        .frame(width: 600, height: 500)
    }
}

struct HelpContentView: NSViewRepresentable {
    let htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.loadHTMLString(htmlContent, baseURL: nil)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}
```

- [ ] **Step 2: 创建 cppreference 帮助 HTML**

创建 `DevMac++/Resources/help/index.html`：

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>C++ 参考手册</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: #1e1e1e;
            color: #cccccc;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            font-size: 13px;
            line-height: 1.6;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        h1 {
            font-size: 24px;
            color: #ffffff;
            margin-bottom: 8px;
        }
        .subtitle {
            color: #858585;
            font-size: 12px;
            margin-bottom: 32px;
        }
        h2 {
            font-size: 16px;
            color: #4ec9b0;
            margin: 24px 0 12px;
            padding-bottom: 4px;
            border-bottom: 1px solid #3e3e42;
        }
        .category {
            margin: 8px 0;
        }
        .category-title {
            color: #9cdcfe;
            font-size: 13px;
            margin: 12px 0 4px;
        }
        a {
            color: #4ec9b0;
            text-decoration: none;
        }
        a:hover {
            color: #6ad6c0;
            text-decoration: underline;
        }
        .note {
            background: rgba(214, 157, 46, 0.1);
            border-left: 3px solid #d69e2e;
            padding: 8px 12px;
            margin: 12px 0;
            font-size: 12px;
        }
        .search-box {
            background: #3c3c3c;
            border: 1px solid #3e3e42;
            color: #cccccc;
            padding: 8px 12px;
            border-radius: 4px;
            width: 100%;
            font-size: 13px;
            margin-bottom: 24px;
        }
        .search-box:focus {
            outline: none;
            border-color: #007acc;
        }
        .toc {
            background: #252526;
            padding: 16px;
            border-radius: 4px;
            margin-bottom: 24px;
        }
        .toc-item {
            padding: 4px 0;
            color: #4ec9b0;
            cursor: pointer;
        }
        .toc-item:hover {
            color: #6ad6c0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>C++ 参考手册</h1>
        <p class="subtitle">基于 cppreference.com · DevMac++ 内置帮助</p>

        <input type="text" class="search-box" placeholder="搜索 (输入关键字过滤)..." id="searchBox" oninput="filterContent()">

        <div class="toc" id="toc">
            <div class="toc-item" onclick="scrollTo('containers')">容器 (Containers)</div>
            <div class="toc-item" onclick="scrollTo('algorithms')">算法 (Algorithms)</div>
            <div class="toc-item" onclick="scrollTo('strings')">字符串 (Strings)</div>
            <div class="toc-item" onclick="scrollTo('io')">输入输出 (I/O)</div>
            <div class="toc-item" onclick="scrollTo('utilities')">工具类 (Utilities)</div>
            <div class="toc-item" onclick="scrollTo('compiling')">编译选项</div>
        </div>

        <div id="content">
            <section id="containers">
                <h2>容器 (Containers)</h2>

                <div class="category">
                    <div class="category-title">序列容器</div>
                    <p><code>vector&lt;T&gt;</code> - 动态数组，支持随机访问<br>
                    <code>deque&lt;T&gt;</code> - 双端队列<br>
                    <code>list&lt;T&gt;</code> - 双向链表<br>
                    <code>array&lt;T, N&gt;</code> - 固定大小数组</p>
                </div>

                <div class="category">
                    <div class="category-title">关联容器</div>
                    <p><code>set&lt;T&gt;</code> - 有序集合<br>
                    <code>map&lt;K, V&gt;</code> - 有序键值对<br>
                    <code>unordered_set&lt;T&gt;</code> - 哈希集合<br>
                    <code>unordered_map&lt;K, V&gt;</code> - 哈希映射</p>
                </div>

                <div class="category">
                    <div class="category-title">常用操作</div>
                    <p><code>v.push_back(x)</code> - 末尾添加<br>
                    <code>v.size()</code> - 获取大小<br>
                    <code>v.empty()</code> - 判断是否为空<br>
                    <code>v.clear()</code> - 清空容器<br>
                    <code>v.begin() / v.end()</code> - 迭代器</p>
                </div>
            </section>

            <section id="algorithms">
                <h2>算法 (Algorithms)</h2>

                <div class="category">
                    <div class="category-title">排序与搜索</div>
                    <p><code>sort(v.begin(), v.end())</code> - 排序<br>
                    <code>reverse(v.begin(), v.end())</code> - 反转<br>
                    <code>unique(v.begin(), v.end())</code> - 去重<br>
                    <code>binary_search(v.begin(), v.end(), x)</code> - 二分查找</p>
                </div>

                <div class="category">
                    <div class="category-title">数值运算</div>
                    <p><code>accumulate(v.begin(), v.end(), 0)</code> - 求和<br>
                    <code>max_element(v.begin(), v.end())</code> - 最大值<br>
                    <code>min_element(v.begin(), v.end())</code> - 最小值</p>
                </div>

                <div class="category">
                    <div class="category-title">查找与计数</div>
                    <p><code>find(v.begin(), v.end(), x)</code> - 查找元素<br>
                    <code>count(v.begin(), v.end(), x)</code> - 计数<br>
                    <code>lower_bound(v.begin(), v.end(), x)</code> - 下界<br>
                    <code>upper_bound(v.begin(), v.end(), x)</code> - 上界</p>
                </div>
            </section>

            <section id="strings">
                <h2>字符串 (Strings)</h2>

                <div class="category">
                    <div class="category-title">string 常用方法</div>
                    <p><code>s.length() / s.size()</code> - 长度<br>
                    <code>s.substr(pos, len)</code> - 子串<br>
                    <code>s.find(str)</code> - 查找子串<br>
                    <code>s.replace(pos, len, str)</code> - 替换<br>
                    <code>s.erase(pos, len)</code> - 删除<br>
                    <code>s.insert(pos, str)</code> - 插入<br>
                    <code>to_string(x)</code> - 转字符串<br>
                    <code>stoi(s) / stoll(s) / stod(s)</code> - 字符串转数值</p>
                </div>

                <div class="category">
                    <div class="note">C++11 起可用 <code>auto</code> 关键字简化迭代器类型：<code>for (auto&amp; x : v)</code></div>
                </div>
            </section>

            <section id="io">
                <h2>输入输出 (I/O)</h2>

                <div class="category">
                    <div class="category-title">标准输入输出</div>
                    <p><code>cin &gt;&gt; x</code> - 读取（跳过空格）<br>
                    <code>cout &lt;&lt; x</code> - 输出<br>
                    <code>getline(cin, s)</code> - 读取整行<br>
                    <code>scanf("%d", &amp;x)</code> - C 风格快速输入<br>
                    <code>printf("%d\n", x)</code> - C 风格快速输出</p>
                </div>

                <div class="category">
                    <div class="category-title">常用技巧</div>
                    <p><code>ios::sync_with_stdio(false); cin.tie(nullptr);</code> - 加速 IO<br>
                    <code>endl</code> - 换行（刷新缓冲区）<br>
                    <code>setprecision(n)</code> - 控制浮点精度<br>
                    <code>fixed</code> - 固定小数格式</p>
                </div>
            </section>

            <section id="utilities">
                <h2>工具类 (Utilities)</h2>

                <div class="category">
                    <div class="category-title">pair 和 tuple</div>
                    <p><code>pair&lt;T1, T2&gt;</code> - 二元组<br>
                    <code>make_pair(a, b)</code> - 创建 pair<br>
                    <code>tuple&lt;T1, T2, T3&gt;</code> - 多元组<br>
                    <code>make_tuple(a, b, c)</code> - 创建 tuple</p>
                </div>

                <div class="category">
                    <div class="category-title">智能指针 (C++11)</div>
                    <p><code>unique_ptr&lt;T&gt;</code> - 独占所有权的智能指针<br>
                    <code>shared_ptr&lt;T&gt;</code> - 共享所有权的智能指针<br>
                    <code>make_unique&lt;T&gt;(args)</code> - 创建 unique_ptr<br>
                    <code>make_shared&lt;T&gt;(args)</code> - 创建 shared_ptr</p>
                </div>

                <div class="category">
                    <div class="category-title">Lambda 表达式 (C++11)</div>
                    <p><code>[](int x) { return x * 2; }</code> - 基本形式<br>
                    <code>[&amp;](int x) { return x + y; }</code> - 按引用捕获<br>
                    <code>[=](int x) { return x + y; }</code> - 按值捕获</p>
                </div>
            </section>

            <section id="compiling">
                <h2>编译选项</h2>

                <div class="category">
                    <div class="category-title">DevMac++ 编译器配置</div>
                    <p><strong>标准：</strong>C++11（固定，不可更改）<br>
                    <strong>GCC 路径：</strong>Homebrew 安装的 g++<br>
                    <strong>调试：</strong>-g 选项（仅调试时添加）<br>
                    <strong>优化：</strong>默认 -O0（可配置）</p>
                </div>

                <div class="note">
                    竞赛注意事项：确保使用 <code>-std=c++11</code> 或更高标准以支持 C++11 特性
                </div>
            </section>
        </div>
    </div>

    <script>
        function scrollTo(id) {
            document.getElementById(id).scrollIntoView({ behavior: 'smooth' });
        }

        function filterContent() {
            const query = document.getElementById('searchBox').value.toLowerCase();
            const sections = document.querySelectorAll('#content section');
            sections.forEach(section => {
                const text = section.textContent.toLowerCase();
                section.style.display = text.includes(query) || query === '' ? 'block' : 'none';
            });
            const toc = document.getElementById('toc');
            if (query === '') {
                toc.style.display = 'block';
            }
        }
    </script>
</body>
</html>
```

- [ ] **Step 3: 更新 AppMenuCommands 添加帮助菜单**

修改 `AppMenuCommands.swift`，在 Commands builder 中添加：

```swift
CommandMenu("帮助") {
    Button("C/C++ 参考手册") {
        openHelpWindow()
    }

    Button("关于 DevMac++") {
        // 显示 about
    }
}
```

添加方法：

```swift
func openHelpWindow() {
    if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "help") {
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 4: 更新 project.yml 添加 help 资源**

在 `project.yml` 的 resources 部分添加：

```yaml
- path: DevMac++/Resources/help
  excludes:
    - "**/.gitkeep"
```

- [ ] **Step 5: 构建验证**

Cmd+B，确认无错误。

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add C++ reference help system"
```

---

## 完成标准

Plan 5 完成后，应用应该：

- [ ] Cmd+F 打开查找栏，输入文字实时高亮所有匹配
- [ ] 查找栏支持上一个/下一个导航，替换当前/全部替换
- [ ] Esc 关闭查找栏
- [ ] 新建文件时显示模板选择面板
- [ ] 默认提供"空白文件"模板（包含竞赛常用头文件）
- [ ] 模板保存在 ~/Library/Application Support/DevMac++/templates.json
- [ ] 帮助 → C/C++ 参考手册打开本地 HTML 文档
- [ ] 帮助文档支持搜索过滤
- [ ] 帮助文档包含：容器、算法、字符串、IO、工具类、编译选项
- [ ] 编译成功，推送 GitHub

**所有计划完成！**
