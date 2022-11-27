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
    static let isGitRepo = "git rev-parse --is-inside-work-tree"

    // Will print hash if it exists, otherwise nothing
    static let doesMainExist = "git rev-parse --verify --quiet main"
    static let main = "main"

    static let currentBranch = "git rev-parse --abbrev-ref HEAD"

    static let lastestTag = "git describe --tags --abbrev=0 --always"

    static let localBranchHash = "git rev-parse @"
    static let remoteBranchHash = "git rev-parse @{u}"
    // gives you the hash you need to merge on top of, if local hash is equal, pull, otherwise a push is needed and we'll just ignore this
    // https://stackoverflow.com/questions/3258243/check-if-pull-needed-in-git
    static let mergeBaseHash = "git merge-base @ @{u}"

    static let remoteUpdate = "git remote update"
    static let remoteBranch = "git branch -r"

    static let pull = "git pull"

    static func checkout(_ branch: String) -> String {
        "git checkout \(branch)"
    }

    static func branch(_ branch: String) -> String {
        "git branch \(branch)"
    }
}

extension String {
    func matches<T>(regex: T) -> Bool where T: StringProtocol {
        range(of: regex, options: .regularExpression) != nil
    }
}

// https://betterprogramming.pub/creating-a-swifty-command-line-tool-with-argumentparser-a6240b512b0b
// - Beginning tutorial
// https://rderik.com/blog/understanding-the-swift-argument-parser-and-working-with-stdin/
// - Getting standard input
struct VersionBranch: ParsableCommand {
    static let scriptName = "versionbranch"
    static let fatalRegex = #"fatal"#

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

    @Flag(name: .shortAndLong, help: "Will skip all prompts and assume you'd like to proceed.")
    var skipPrompts = false

    // TODO: Will need to verify string is in correct format, verify path exists, then run the comment in that directly (probably some bash arument
    @Argument(help: "The path to the git repo.")
    var gitPath: String?

    @Flag(name: .shortAndLong, help: "Used to diagnose issues with the running script")
    var verbose = false

    // Validate file path
    func validate() throws {
        verbosePrint("Starting command validation.")
        var errors = [String]()

        verbosePrint("Checking for git-path.")
        if let gitPath {
            verbosePrint("git-path found: \(gitPath)")
            var isDirectory = ObjCBool(false)

            if FileManager.default.fileExists(atPath: gitPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    verbosePrint("Successfully validated git-path.")
                    try shell("cd \(gitPath)")
                } else {
                    errors.append("Path is not a directory: \(gitPath)")
                }
            } else {
                errors.append("Directory does not exist: \(gitPath)")
            }
        } else {
            verbosePrint("No git-path provided.")
        }

        verbosePrint("Checking that path contains git repo.")
        // We only want to check for the git repo if there isn't already a gitPath error
        if errors.isEmpty {
            if try shell(Git.isGitRepo).matches(regex: #"(true)"#) {
                verbosePrint("Successfully validated git repo.")
            } else {
                errors.append("This is not a git repo. \(Self.scriptName) must be run within a git repo.")
            }
        }  else {
            verbosePrint("Skipping git repo validation due to git-path error.")
        }

        verbosePrint("Checking version component flag.")
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
        } else {
            verbosePrint("Successfully validated version component flag.")
        }

        verbosePrint("Checking for validation errors.")

        guard errors.isEmpty else {
            verbosePrint("Found \(errors.count) validation errors.")
            for error in errors {
                print(error)
            }
            throw ExitCode.validationFailure
        }

        verbosePrint("No validation errors found.")
    }

    mutating func run() throws {
        verbosePrint("Starting command run.")

        verbosePrint("Checking the current branch.")
        let currentBranch = try shell(Git.currentBranch).trimmingCharacters(in: .whitespacesAndNewlines)

        // TODO: Add a shortcut for trimming whitespace in a utils package
        if currentBranch != Git.main {
            if promptToProceed("You are currently on the branch, \"\(currentBranch)\". Would you like to checkout the \"main\" branch") {
                if try !shell(Git.doesMainExist).isEmpty {
                    print(try shell(Git.checkout(Git.main)))
                } else {
                    print("The main branch does not exist.")
                    throw ExitCode.failure
                }
            }
        }
        verbosePrint("Finished checking the current branch.")

        verbosePrint("Checking for remote branch")
        let remoteBranch = try shell(Git.remoteBranch).trimmingCharacters(in: .whitespacesAndNewlines)

        // TODO: check if remote exists, if not skip pull
        if !remoteBranch.isEmpty {
            verbosePrint("Found remote \"\(remoteBranch)\".")
            verbosePrint("Updating remote refs.")
            if try !shell(Git.remoteUpdate).matches(regex: Self.fatalRegex) {
                verbosePrint("Successfully updated remote refs.")
                let localBranchHash = try shell(Git.localBranchHash)
                let remoteBranchHash = try shell(Git.remoteBranchHash)
                let mergeBaseHash = try shell(Git.mergeBaseHash)

                // If local hash is behind the remote, it'll be the merge base
                if localBranchHash != remoteBranchHash
                    && localBranchHash == mergeBaseHash
                && promptToProceed("Local branch is out of date with remote, do a pull?"){
                    verbosePrint("Pulling remote for updates.")
                    if try shell(Git.pull).contains(Self.fatalRegex) {
                        print("Exiting: Unable to pull from remote \"\(remoteBranch)\".")
                    } else {
                        verbosePrint("Successfully pulled for updates.")
                    }
                }
            } else if !promptToProceed("Unable to connect to remote, do you want to proceed?", defaultValue: false) {
                print("Exiting: Failed to update remote refs for \"\(remoteBranch)\".")
                throw ExitCode.failure
            }
        } else {
            verbosePrint("No remote branch exists for\(currentBranch).")
        }

        verbosePrint("Retrieving version tag.")
        let tag = try getVersionTag()
        verbosePrint("Current version tag is \"\(tag.string)\"")

        verbosePrint("Getting next version tag")
        let nextTag: VersionTag

        if major {
            nextTag = tag.nextMajor
        } else if minor {
            nextTag = tag.nextMinor
        } else {
            nextTag = tag.nextFix
        }

        verbosePrint("Next version tag is\"\(nextTag.string)\".")

        verbosePrint("Creating branch for \"\(nextTag.string)\".")

        // TODO: Create branch for tag
        if try !shell(Git.branch(nextTag.string)).matches(regex: Self.fatalRegex) {
            verbosePrint("Successfully created \"\(nextTag.string)\" branch.")
        } else {
            print("Exiting: Failed to create \"\(nextTag.string)\"")
        }

        verbosePrint("Finished creating branch for \"\(nextTag.string)\".")

        verbosePrint("Checking out \"\(nextTag.string)\" branch.")

        if try !shell(Git.checkout(nextTag.string)).matches(regex: Self.fatalRegex) {
            verbosePrint("Successfully checked out \"\(nextTag.string)\" branch")
        } else {
            print("Exiting: Failed to create \"\(nextTag.string)\".")
        }

        verbosePrint("Finished checking out \"\(nextTag.string)\" branch.")

        throw ExitCode.success
    }

    func getVersionTag() throws -> VersionTag {
        let latestTag = try shell(Git.lastestTag)
        if !latestTag.matches(regex: #"\d+\.\d+\.\d+"#) {
            if promptToProceed("No version tag found in the format \"X.X.X\". A new tag will be created in that format, proceed?") {
                return VersionTag(major: 0, minor: 0, fix: 0)
            } else {
                throw ExitCode.success
            }
        }

        let tagComponents = latestTag.split(separator: ".")

        guard tagComponents.count == 3 else {
            print("Version tags must be in the format \"X.X.X\" with 3 components. Found \(tagComponents.count) instead.")
            throw ExitCode.failure
        }

        guard let major = Int(tagComponents[0]),
              let minor = Int(tagComponents[1]),
              let fix = Int(tagComponents[2])
        else {
            print("Tag components, must all be numbers. Latest tag is \(latestTag) ")
            throw ExitCode.failure
        }

        return VersionTag(major: major, minor: minor, fix: fix)
    }

    func promptToProceed(_ prompt: String, defaultValue: Bool = true) -> Bool {
        guard !skipPrompts else {
            return defaultValue
        }

        print("\(prompt) Type yes (y) or no (n):", terminator: " ")

        let yesOrNo = readLine()

        // Case insensitive match
        if yesOrNo?.matches(regex: #"(?i)(yes|y|no|n)(?-i)"#) != true {
            print("You must type yes or no to proceed.")
            return promptToProceed(prompt)
        }

        return yesOrNo!.matches(regex: #"(yes|y)"#)
    }

    // From https://betterprogramming.pub/command-line-tool-with-argument-parser-in-swift-b0e1c27aebd
    @discardableResult
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

    func verbosePrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        guard verbose else {
            return
        }

        print(items, separator: separator, terminator: terminator)
    }
}

struct VersionTag {
    let major: Int
    let minor: Int
    let fix: Int

    var nextMajor: VersionTag {
        VersionTag(major: major + 1, minor: minor, fix: fix)
    }

    var nextMinor: VersionTag {
        VersionTag(major: major, minor: minor + 1, fix: fix)
    }

    var nextFix: VersionTag {
        VersionTag(major: major, minor: minor, fix: fix + 1)
    }

    var string: String {
        "\(major).\(minor).\(fix)"
    }
}
