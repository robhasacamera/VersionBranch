//
// VersionBranch
//
// MIT License
//
// Copyright (c) 2022 Robert Cole
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
//

import ArgumentParser
import Foundation

// https://betterprogramming.pub/creating-a-swifty-command-line-tool-with-argumentparser-a6240b512b0b
// - Beginning tutorial
// https://rderik.com/blog/understanding-the-swift-argument-parser-and-working-with-stdin/
// - Getting standard input
struct VersionBranch: ParsableCommand {
    static let lastestTagCommand = "git describe --tags --abbrev=0"

    static let configuration = CommandConfiguration(
        commandName: "versionbranch",
        abstract: "Creates a new branch for the new version.",
        usage: nil,
        discussion: "Automatically increments the version number for a swift package and creates a new branch for it.",
        version: "0.0.1",
        shouldDisplay: true,
        subcommands: [],
        defaultSubcommand: nil,
        helpNames: .shortAndLong
    )

    // TODO: Make these subcommands, though that would make additional flags/options more difficult to implement
    @Flag(name: .shortAndLong, help: "Increments version number to the next major version: 1.0.0 would become 2.0.0")
    var major = false

    @Flag(name: [.customShort("n"), .long], help: "Increments version number to the next minor version: 1.0.0 would become 1.1.0")
    var minor = false

    @Flag(name: .shortAndLong, help: "Increments version number to the next fix version: 1.0.0 would become 1.0.1")
    var fix = false

    // TODO: Add option to provide the filepath to repo
    // TODO: Provide an option to automatically checkout main and do a pull

    // TODO: Collect error messages, provide them all if multiple.
    // TODO: Check if only one version (major, minor, fix) was given
    // TODO: Check if git repo
    // TODO: Check if latest tag matches regex
    func validate() throws {
        print("first")
    }

    mutating func run() throws {
        print(try shell(Self.lastestTagCommand))

        // TODO: Check if on main, if not, prompt to checkout main
        // TODO: Check if needs pull, if so, prompt to pull
        // if I need user input
        // let _ = readLine()
        throw ExitCode.success
    }

    // From https://betterprogramming.pub/command-line-tool-with-argument-parser-in-swift-b0e1c27aebd
    func shell(_ command: String) throws -> String {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()

        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        guard let output = String(data: data, encoding: .utf8) else {
            throw CustomError.shellOutputFailed
        }

        return output
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}

// TODO: Rename
enum CustomError: Swift.Error {
    case shellOutputFailed
}
