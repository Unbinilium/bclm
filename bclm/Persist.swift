//
// Modified by Unbinilium, 2024
//
// MIT License
//
// Copyright (c) 2020 Zack Elia
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

private let launchctl = "/bin/launchctl"
private let plist = "com.unbinilium.bclm.plist"
private let plist_path = "/Library/LaunchDaemons/\(plist)"

struct Preferences: Codable {
    var Label: String
    var RunAtLoad: Bool
    var ProgramArguments: [String]
}

func setPersist(_ enable: Bool) {
    if isPersistent() && enable {
        print("Already persisted.")
        return
    }
    if !isPersistent() && !enable {
        print("Already not persisted.")
        return
    }

    let process = Process()
    let pipe = Pipe()
    let load = enable ? "load" : "unload"

    process.launchPath = launchctl
    process.arguments = [load, plist_path]
    process.standardOutput = pipe
    process.standardError = pipe

    process.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

    if (output != nil && !output!.isEmpty) {
        print(output!)
    }

    if !enable {
        do {
            try FileManager.default.removeItem(at: URL(fileURLWithPath: plist_path))
        } catch {
            print("Error: \(error)", to: &stderrOutputStream)
        }
    }
}

func isPersistent() -> Bool {
    let process = Process()
    let pipe = Pipe()

    process.launchPath = launchctl
    process.arguments = ["list"]
    process.standardOutput = pipe
    process.standardError = pipe

    process.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

    guard let output = output, output.contains(plist) else {
        return false
    }
    return true
}

func updatePersist(_ value: Int) {
    let preferences = Preferences(
        Label: plist,
        RunAtLoad: true,
        ProgramArguments: [
            Bundle.main.executablePath! as String,
            "write",
            String(value)
        ]
    )

    let path = URL(fileURLWithPath: plist_path)
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .xml

    do {
        let data = try encoder.encode(preferences)
        try data.write(to: path)
    } catch {
        print("Error: \(error)", to: &stderrOutputStream)
    }
}
