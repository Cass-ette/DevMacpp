import Foundation

struct CompilerOptions {
    // 固定 C++11
    static let standard = "c++11"

    var optimizationLevel: String = "-O0"  // -O0, -O1, -O2, -O3
    var enableWall: Bool = false
    var enableWextra: Bool = false
    var additionalFlags: String = ""

    func toArguments() -> [String] {
        var args: [String] = ["-std=\(CompilerOptions.standard)"]
        args.append(optimizationLevel)
        if enableWall { args.append("-Wall") }
        if enableWextra { args.append("-Wextra") }
        if !additionalFlags.isEmpty {
            args.append(contentsOf: additionalFlags.components(separatedBy: " "))
        }
        return args
    }
}
