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

enum Git {
    static let isGitRepo = "git rev-parse --is-inside-work-tree --quiet"

    // Will print hash if it exists, otherwise nothing
    static let doesMainExist = "git rev-parse --verify --quiet main"
    static let checkoutMain = "git checkout main"
    static let main = "main"

    static let lastestTag = "git describe --tags --abbrev=0"

    static let currentBranch = "git rev-parse --abbrev-ref HEAD"

    static let localBranchHash = "git rev-parse @"
    static let remoteBranchHash = "git rev-parse @{u}"
    // gives you the hash you need to merge on top of, if local hash is equal, pull, otherwise a push is needed and we'll just ignore this
    // https://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
    static let mergeBaseHash = "git merge-base @ @{u}"

    static let pull = "git pull"
}

// https://betterprogramming.pub/creating-a-swifty-command-line-tool-with-argumentparser-a6240b512b0b
// - Beginning tutorial
// https://rderik.com/blog/understanding-the-swift-argument-parser-and-working-with-stdin/
// - Getting standard input
struct VersionBranch: ParsableCommand {
    static let scriptName = "versionbranch"

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

    // TODO: Will need to verify string is in correct format, verify path exists, then run the comment in that directly (probably some bash arument
    @Argument(help: "The path to the git repo.")
    var gitPath: String?

    // TODO: Add option to provide the filepath to repo
    // TODO: Provide an option to automatically checkout main and do a pull

    // TODO: Collect error messages, provide them all if multiple.
    // TODO: Check if only one version (major, minor, fix) was given
    // TODO: Check if git repo
    // TODO: Check if latest tag matches regex
    func validate() throws {
        var errors = [String]()

        if try shell(Git.isGitRepo) == "true" {
            if try !shell(Git.doesMainExist).isEmpty {

                // Move tag check to different function. It can provide the version components, 0.0.0 if no previous tags exist, or throws if the format is incorrect
                let latestTag = try shell(Git.lastestTag)

                if !latestTag.isEmpty {

                    if #available(macOS 13.0, *) {
                        if latestTag.matches(of: #/\d+\.\d+\.\d+/#).isEmpty {
                            errors.append("Tags must be in the format X.X.X, examples: 1.0.1, 2.3.0, 0.0.1")
                        }
                    } else {
                        errors.append("\(Self.scriptName) requires Mac 13.0+.")
                    }
                }
            } else {
                errors.append("The main branch does not exist. \(Self.scriptName) requires a main branch to exist")
            }
        } else {
            errors.append("This is not a git repo. \(Self.scriptName) must be run within a git repo.")
        }

        let versionFlags = [major, minor, fix]

        var trueCount = 0

        for flag in versionFlags {
            if flag {
                trueCount += 1
            }
        }

        if trueCount < 1 {
            errors.append("A version flag must be provided, use -m (--major), -n (--minor), or -f (--fix).")
        } else if trueCount > 1 {
            errors.append("Too many version flags provided. Please provide only one version flag, -m (--major), -n (--minor), or -f (--fix).")
        }

        guard errors.isEmpty else {
            for error in errors {
                print(error)
            }
            throw ExitCode.validationFailure
        }

        throw ExitCode.success
    }

    mutating func run() throws {


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
            print("Could not get output for command: \(command)")
            throw ExitCode.failure
        }

        return output
    }
}
