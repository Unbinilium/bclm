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

import ArgumentParser
import Foundation

struct StderrOutputStream: TextOutputStream {
    mutating func write(_ string: String) { fputs(string, stderr) }
}

var stderrOutputStream = StderrOutputStream()

struct BCLM: ParsableCommand {

    public enum BCLMError: Error {
        case notSupported(code: String)
        case notPrivileged(code: String)
    }

    static let configuration = CommandConfiguration(
        abstract: "Battery Charge Level Max (BCLM) Utility.",
        version: "2024.3.9",
        subcommands: [Read.self, Write.self, Persist.self, Unpersist.self])

    static let BCLM_KEY = "CHWA"

    static func validateArch() throws {
#if !arch(arm64)
        throw BCLMError.notSupported(code: "Only support ARM based Macs.")
#endif
    }

    static func validateRoot() throws {
        guard getuid() == 0 else {
            throw BCLMError.notPrivileged(code: "Must run as root.")
        }
    }

    func validate() throws {
        try BCLM.validateArch()
    }

    struct Read: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Reads the BCLM value.")

        func run() throws {
            do {
                let client = try SMCKit()
                let key = SMCKey.fromString(BCLM_KEY, type: DataTypes.UInt8)
                let status = try client.readData(key).0
                let limit = status == 1 ? 80 : 100

                print(limit)
            } catch {
                print("Error: \(error)", to: &stderrOutputStream)
            }
        }
    }

    struct Write: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Writes a BCLM value.")

        @Argument(help: "The value to set (80 or 100).")
        var value: Int


        func validate() throws {
            try BCLM.validateRoot()

            guard value == 80 || value == 100 else {
                throw ValidationError("Value must be either 80 or 100.")
            }
        }

        func run() {
            do {
                let client = try SMCKit()
                let key = SMCKey.fromString(BCLM_KEY, type: DataTypes.UInt8)
                let data: SMCBytes = (
                    UInt8(value == 80 ? 1 : 0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0)
                )
                try client.writeData(key, data: data)

                if (isPersistent()) {
                    updatePersist(value)
                }
            } catch {
                print("Error: \(error)", to: &stderrOutputStream)
            }
        }
    }

    struct Persist: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Persists on reboot.")

        func validate() throws {
            try BCLM.validateRoot()
        }

        func run() {
            do {
                let client = try SMCKit()
                let key = SMCKey.fromString(BCLM_KEY, type: DataTypes.UInt8)
                let status = try client.readData(key).0
                let limit = status == 1 ? 80 : 100

                updatePersist(limit)
                setPersist(true)
            } catch {
                print("Error: \(error)", to: &stderrOutputStream)
            }
        }
    }

    struct Unpersist: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Unpersists on reboot.")

        func validate() throws {
            try BCLM.validateRoot()
        }

        func run() {
            setPersist(false)
        }
    }
}
