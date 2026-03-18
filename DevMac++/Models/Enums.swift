import Foundation

enum BottomTab: String, CaseIterable {
    case compileLog = "编译日志"
    case compileResult = "编译结果"
    case runtime = "运行"
    case debug = "调试"
    case findResults = "查找结果"
}

enum SidebarTab: String, CaseIterable {
    case project = "项目"
    case classes = "类"
    case watch = "监视"
    case locals = "局部"
    case callStack = "栈"
}

enum InsertMode: String {
    case insert = "插入"
    case overwrite = "覆盖"
}
