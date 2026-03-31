// Merged test suite for repo-report.fsx
// Unit tests for individual functions + integration test that generates the report.
// Run: dotnet fsi test-report.fsx

open System
open System.IO
open System.Diagnostics
open System.Text

// ============================================================
// Test infrastructure
// ============================================================

let mutable passed = 0
let mutable failed = 0
let mutable errors = ResizeArray<string>()

let green s = $"\x1b[32m{s}\x1b[0m"
let red s = $"\x1b[31m{s}\x1b[0m"
let bold s = $"\x1b[1m{s}\x1b[0m"

let assert' (name: string) (condition: bool) (detail: string) =
    if condition then
        passed <- passed + 1
        printfn "  %s %s" (green "PASS") name
    else
        failed <- failed + 1
        let msg = $"{name}: {detail}"
        errors.Add(msg)
        printfn "  %s %s — %s" (red "FAIL") name detail

let assertEqual (name: string) (expected: 'a) (actual: 'a) =
    assert' name (expected = actual) $"expected {expected}, got {actual}"

let assertContains (name: string) (substring: string) (actual: string) =
    assert' name (actual.Contains(substring)) $"expected to contain '{substring}'"

let assertNotContains (name: string) (substring: string) (actual: string) =
    assert' name (not (actual.Contains(substring))) $"should NOT contain '{substring}'"

let assertNotEmpty (name: string) (actual: string) =
    assert' name (not (String.IsNullOrWhiteSpace(actual))) "was empty"

// ============================================================
// Utility functions (copied from repo-report.fsx)
// ============================================================

let resolveCmd (cmd: string) =
    let paths = [| "/opt/homebrew/bin"; "/usr/local/bin"; "/usr/bin"; "/bin" |]
    match paths |> Array.tryFind (fun p -> File.Exists(Path.Combine(p, cmd))) with
    | Some p -> Path.Combine(p, cmd)
    | None -> cmd

let runShell (cmdLine: string) workDir =
    try
        let tmpFile = Path.GetTempFileName()
        File.WriteAllText(tmpFile, cmdLine)
        let psi = ProcessStartInfo(fileName = "/bin/sh", arguments = tmpFile)
        psi.WorkingDirectory <- workDir
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        let p = Process.Start(psi)
        let output = p.StandardOutput.ReadToEnd()
        p.WaitForExit(30000) |> ignore
        try File.Delete(tmpFile) with _ -> ()
        output.Trim()
    with _ -> ""

let run cmd args workDir =
    let resolved = resolveCmd cmd
    try
        let psi = ProcessStartInfo(fileName = resolved, arguments = (args: string))
        psi.WorkingDirectory <- workDir
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        let p = Process.Start(psi)
        let output = p.StandardOutput.ReadToEnd()
        p.WaitForExit(15000) |> ignore
        output.Trim()
    with _ -> ""

let isGitRepo dir =
    Directory.Exists(Path.Combine(dir, ".git"))

let getModifiedCount dir =
    let output = run "git" "status --porcelain" dir
    if String.IsNullOrWhiteSpace(output) then 0
    else output.Split('\n') |> Array.filter (fun l -> l.Trim() <> "") |> Array.length

let getLastEditDate dir =
    let output = run "git" "log -1 --format=%ci HEAD" dir
    if String.IsNullOrWhiteSpace(output) then "unknown"
    else
        let parts = output.Split(' ')
        if parts.Length > 0 then parts.[0] else output

let getBranch dir =
    let b = run "git" "rev-parse --abbrev-ref HEAD" dir
    if String.IsNullOrWhiteSpace(b) then "unknown" else b

let getPushStatus dir =
    let ahead = run "git" "rev-list @{u}..HEAD --count" dir
    let behind = run "git" "rev-list HEAD..@{u} --count" dir
    match ahead, behind with
    | a, _ when a <> "" && a <> "0" -> "Ahead " + a
    | _, b when b <> "" && b <> "0" -> "Behind " + b
    | "", _ -> "No upstream"
    | _ -> "Up to date"

let escape (s: string) =
    s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")

type CommunityItem = {
    Number: string; Title: string; Author: string
    Repo: string; Url: string; CreatedAt: string
}

let parseCommunityItem (tsv: string) : CommunityItem option =
    if String.IsNullOrWhiteSpace(tsv) then None
    else
        let parts = tsv.Split('\t')
        if parts.Length < 6 then None
        else
            let clean (s: string) = if String.IsNullOrWhiteSpace(s) || s = "null" then "" else s.Trim()
            Some { Number = clean parts.[0]; Title = clean parts.[1]; Author = clean parts.[2]
                   Repo = clean parts.[3]; Url = clean parts.[4]; CreatedAt = clean parts.[5] }

let filterCommunity (excludeAuthor: string) (items: CommunityItem[]) : CommunityItem[] =
    items |> Array.filter (fun item -> item.Author.ToLowerInvariant() <> excludeAuthor.ToLowerInvariant())

let formatCreatedAt (s: string) =
    if s.Length >= 10 then s.[0..9] else s

let aggregateCI (conclusions: string[]) (statuses: string[]) =
    let states = conclusions |> Array.map (fun s -> s.Trim().ToUpperInvariant()) |> Array.filter (fun s -> s <> "" && s <> "NULL")
    let statusArr = statuses |> Array.map (fun s -> s.Trim().ToUpperInvariant()) |> Array.filter (fun s -> s <> "" && s <> "NULL")
    let hasInProgress = statusArr |> Array.exists (fun s -> s = "IN_PROGRESS" || s = "PENDING" || s = "QUEUED")
    if states |> Array.exists (fun s -> s = "FAILURE" || s = "ERROR" || s = "STARTUP_FAILURE") then "FAILURE"
    elif states |> Array.exists (fun s -> s = "CANCELLED") then "CANCELLED"
    elif hasInProgress then "IN_PROGRESS"
    elif states |> Array.exists (fun s -> s = "SUCCESS") then "SUCCESS"
    elif states.Length > 0 then states.[0]
    else ""

// ============================================================
// Temp directory helpers
// ============================================================

let tempRoot = Path.Combine(Path.GetTempPath(), "repo-report-tests-" + Guid.NewGuid().ToString("N").[..7])
Directory.CreateDirectory(tempRoot) |> ignore

let createTempDir name =
    let d = Path.Combine(tempRoot, name)
    Directory.CreateDirectory(d) |> ignore
    d

let git = resolveCmd "git"

let gitInit dir =
    run "git" "init" dir |> ignore
    run "git" "-c user.email=test@test.com -c user.name=Test commit --allow-empty -m \"initial\"" dir |> ignore

let gitInitWithFile dir fileName (content: string) =
    gitInit dir
    File.WriteAllText(Path.Combine(dir, fileName), content)
    run "git" $"add {fileName}" dir |> ignore
    run "git" "-c user.email=test@test.com -c user.name=Test commit -m \"add file\"" dir |> ignore

let today = DateTime.Now.ToString("yyyy-MM-dd")

printfn ""
printfn "%s" (bold "=== repo-report.fsx — Full Test Suite ===")
printfn ""

// ============================================================
// PART 1: UNIT TESTS
// ============================================================

// ----------------------------------------------------------
printfn "%s" (bold "1. resolveCmd")
// ----------------------------------------------------------

let gitPath = resolveCmd "git"
assert' "resolveCmd finds git" (File.Exists(gitPath)) $"path={gitPath}"
assertEqual "resolveCmd returns raw name for missing cmd" "surely_no_such_binary_abc123" (resolveCmd "surely_no_such_binary_abc123")

// ----------------------------------------------------------
printfn "\n%s" (bold "2. run")
// ----------------------------------------------------------

assertEqual "run captures stdout" "hello world" (run "echo" "hello world" "/")
assertEqual "run returns empty on failure exit" "" (run "false" "" "/")
assertEqual "run returns empty on missing command" "" (run "surely_no_such_binary_abc123" "" "/")

// ----------------------------------------------------------
printfn "\n%s" (bold "3. isGitRepo")
// ----------------------------------------------------------

let gitDir = createTempDir "real-repo"
gitInit gitDir
assert' "isGitRepo true for git repo" (isGitRepo gitDir) ""

let plainDir = createTempDir "not-a-repo"
assert' "isGitRepo false for non-repo" (not (isGitRepo plainDir)) ""

let emptyDir = createTempDir "empty-dir"
assert' "isGitRepo false for empty dir" (not (isGitRepo emptyDir)) ""

let fakeGit = createTempDir "fake-git"
File.WriteAllText(Path.Combine(fakeGit, ".git"), "gitdir: /somewhere")
assert' "isGitRepo false when .git is a file" (not (isGitRepo fakeGit)) ""

// ----------------------------------------------------------
printfn "\n%s" (bold "4. getModifiedCount")
// ----------------------------------------------------------

let cleanRepo = createTempDir "clean-repo"
gitInitWithFile cleanRepo "file.txt" "hello"
assertEqual "getModifiedCount 0 for clean repo" 0 (getModifiedCount cleanRepo)

File.WriteAllText(Path.Combine(cleanRepo, "untracked.txt"), "new")
assert' "getModifiedCount counts untracked" (getModifiedCount cleanRepo >= 1) $"got {getModifiedCount cleanRepo}"

File.WriteAllText(Path.Combine(cleanRepo, "file.txt"), "modified")
assert' "getModifiedCount counts modified + untracked" (getModifiedCount cleanRepo >= 2) $"got {getModifiedCount cleanRepo}"

let stagedRepo = createTempDir "staged-repo"
gitInitWithFile stagedRepo "a.txt" "aaa"
File.WriteAllText(Path.Combine(stagedRepo, "b.txt"), "bbb")
run "git" "add b.txt" stagedRepo |> ignore
assert' "getModifiedCount includes staged files" (getModifiedCount stagedRepo >= 1) $"got {getModifiedCount stagedRepo}"
File.WriteAllText(Path.Combine(stagedRepo, "a.txt"), "modified-a")
assert' "getModifiedCount includes staged + unstaged" (getModifiedCount stagedRepo >= 2) $"got {getModifiedCount stagedRepo}"

let deleteRepo = createTempDir "delete-repo"
gitInitWithFile deleteRepo "tracked.txt" "content"
File.Delete(Path.Combine(deleteRepo, "tracked.txt"))
assert' "getModifiedCount detects deleted file" (getModifiedCount deleteRepo >= 1) $"got {getModifiedCount deleteRepo}"

let renameRepo = createTempDir "rename-repo"
gitInitWithFile renameRepo "old-name.txt" "content"
File.Move(Path.Combine(renameRepo, "old-name.txt"), Path.Combine(renameRepo, "new-name.txt"))
assert' "getModifiedCount detects rename" (getModifiedCount renameRepo >= 1) $"got {getModifiedCount renameRepo}"

// ----------------------------------------------------------
printfn "\n%s" (bold "5. getLastEditDate")
// ----------------------------------------------------------

let dateRepo = createTempDir "date-repo"
gitInitWithFile dateRepo "f.txt" "x"
let lastEdit = getLastEditDate dateRepo
assert' "getLastEditDate returns date string" (lastEdit.Contains("-") && lastEdit.Length >= 10) $"got '{lastEdit}'"
assertEqual "getLastEditDate is today" today lastEdit

let emptyRepo = createTempDir "empty-git-repo"
run "git" "init" emptyRepo |> ignore
assertEqual "getLastEditDate unknown for empty repo" "unknown" (getLastEditDate emptyRepo)

// ----------------------------------------------------------
printfn "\n%s" (bold "6. getBranch")
// ----------------------------------------------------------

let branchRepo = createTempDir "branch-repo"
gitInitWithFile branchRepo "f.txt" "x"
let defaultBranch = getBranch branchRepo
assert' "getBranch returns main or master" (defaultBranch = "main" || defaultBranch = "master") $"got '{defaultBranch}'"

run "git" "checkout -b feature/test-branch" branchRepo |> ignore
assertEqual "getBranch on feature branch" "feature/test-branch" (getBranch branchRepo)

let multiBranchRepo = createTempDir "multi-branch"
gitInitWithFile multiBranchRepo "f.txt" "content"
run "git" "checkout -b dev" multiBranchRepo |> ignore
assertEqual "getBranch dev" "dev" (getBranch multiBranchRepo)
run "git" "checkout -b release/v1.0" multiBranchRepo |> ignore
assertEqual "getBranch release/v1.0" "release/v1.0" (getBranch multiBranchRepo)

let detachedRepo = createTempDir "detached-repo"
gitInitWithFile detachedRepo "f.txt" "x"
let headSha = run "git" "rev-parse HEAD" detachedRepo
run "git" $"checkout {headSha}" detachedRepo |> ignore
assertEqual "getBranch on detached HEAD" "HEAD" (getBranch detachedRepo)

// ----------------------------------------------------------
printfn "\n%s" (bold "7. getPushStatus")
// ----------------------------------------------------------

let pushRepo = createTempDir "push-repo"
gitInitWithFile pushRepo "f.txt" "x"
assertEqual "getPushStatus no upstream" "No upstream" (getPushStatus pushRepo)

let bareDir = createTempDir "bare-remote"
run "git" "init --bare" bareDir |> ignore
let clonedDir = Path.Combine(tempRoot, "cloned-repo")
run "git" $"clone {bareDir} {clonedDir}" tempRoot |> ignore
File.WriteAllText(Path.Combine(clonedDir, "file.txt"), "initial")
run "git" "add file.txt" clonedDir |> ignore
run "git" "-c user.email=test@test.com -c user.name=Test commit -m init" clonedDir |> ignore
let cloneBranch = getBranch clonedDir
run "git" $"push -u origin {cloneBranch}" clonedDir |> ignore

assertEqual "getPushStatus up to date" "Up to date" (getPushStatus clonedDir)

File.WriteAllText(Path.Combine(clonedDir, "file.txt"), "changed")
run "git" "add file.txt" clonedDir |> ignore
run "git" "-c user.email=test@test.com -c user.name=Test commit -m ahead" clonedDir |> ignore
assertEqual "getPushStatus ahead" "Ahead 1" (getPushStatus clonedDir)

run "git" $"push origin {cloneBranch}" clonedDir |> ignore
run "git" "reset --hard HEAD~1" clonedDir |> ignore
assertEqual "getPushStatus behind" "Behind 1" (getPushStatus clonedDir)

// ----------------------------------------------------------
printfn "\n%s" (bold "8. escape")
// ----------------------------------------------------------

assertEqual "escape ampersand" "&amp;" (escape "&")
assertEqual "escape less-than" "&lt;" (escape "<")
assertEqual "escape greater-than" "&gt;" (escape ">")
assertEqual "escape combined" "&lt;b&gt;hello &amp; world&lt;/b&gt;" (escape "<b>hello & world</b>")
assertEqual "escape plain text unchanged" "hello world" (escape "hello world")
assertEqual "escape empty string" "" (escape "")
assertEqual "escape double escape" "&amp;amp;" (escape "&amp;")
assertEqual "escape sequence of specials" "&lt;&amp;&gt;" (escape "<&>")

// ----------------------------------------------------------
printfn "\n%s" (bold "9. CI aggregation logic")
// ----------------------------------------------------------

assertEqual "CI agg: all success" "SUCCESS" (aggregateCI [|"SUCCESS";"SUCCESS"|] [|"COMPLETED";"COMPLETED"|])
assertEqual "CI agg: one failure" "FAILURE" (aggregateCI [|"SUCCESS";"FAILURE"|] [|"COMPLETED";"COMPLETED"|])
assertEqual "CI agg: failure wins over cancelled" "FAILURE" (aggregateCI [|"CANCELLED";"FAILURE"|] [|"COMPLETED";"COMPLETED"|])
assertEqual "CI agg: cancelled" "CANCELLED" (aggregateCI [|"SUCCESS";"CANCELLED"|] [|"COMPLETED";"COMPLETED"|])
assertEqual "CI agg: in_progress" "IN_PROGRESS" (aggregateCI [|"SUCCESS"|] [|"COMPLETED";"IN_PROGRESS"|])
assertEqual "CI agg: pending" "IN_PROGRESS" (aggregateCI [||] [|"PENDING"|])
assertEqual "CI agg: queued" "IN_PROGRESS" (aggregateCI [||] [|"QUEUED"|])
assertEqual "CI agg: empty" "" (aggregateCI [||] [||])
assertEqual "CI agg: error conclusion" "FAILURE" (aggregateCI [|"ERROR"|] [|"COMPLETED"|])
assertEqual "CI agg: startup_failure" "FAILURE" (aggregateCI [|"STARTUP_FAILURE"|] [|"COMPLETED"|])
assertEqual "CI agg: null filtered" "" (aggregateCI [|"null"|] [|"null"|])
assertEqual "CI agg: unknown state passthrough" "SKIPPED" (aggregateCI [|"SKIPPED"|] [|"COMPLETED"|])

// ----------------------------------------------------------
printfn "\n%s" (bold "10. parseCommunityItem")
// ----------------------------------------------------------

let validTsv = "42\tFix the bug\tjsmith\tMelbourneDeveloper/myrepo\thttps://github.com/MelbourneDeveloper/myrepo/issues/42\t2026-03-01T12:00:00Z"
let parsed = parseCommunityItem validTsv
assert' "parseCommunityItem Some for valid TSV" parsed.IsSome "expected Some"
assertEqual "parsed number" "42" parsed.Value.Number
assertEqual "parsed title" "Fix the bug" parsed.Value.Title
assertEqual "parsed author" "jsmith" parsed.Value.Author
assertEqual "parsed repo" "MelbourneDeveloper/myrepo" parsed.Value.Repo
assertEqual "parsed url" "https://github.com/MelbourneDeveloper/myrepo/issues/42" parsed.Value.Url
assertEqual "parsed createdAt" "2026-03-01T12:00:00Z" parsed.Value.CreatedAt

assertEqual "parseCommunityItem None for empty" None (parseCommunityItem "")
assertEqual "parseCommunityItem None for whitespace" None (parseCommunityItem "   ")
assertEqual "parseCommunityItem None for 5 cols" None (parseCommunityItem "1\ttitle\tauthor\trepo\turl")
assertEqual "parseCommunityItem None for 1 col" None (parseCommunityItem "1")
assertEqual "parseCommunityItem None for 4 empty tabs" None (parseCommunityItem "\t\t\t\t")

let nullTsv = "7\tnull\tnull\tnull\tnull\tnull"
let nullParsed = parseCommunityItem nullTsv
assert' "parseCommunityItem Some for null fields" nullParsed.IsSome ""
assertEqual "null title becomes empty" "" nullParsed.Value.Title
assertEqual "null author becomes empty" "" nullParsed.Value.Author

let extraTsv = "99\tTitle\tauthorX\trepo\thttps://x\t2026-01-01T00:00:00Z\textra\tanother"
let extraParsed = parseCommunityItem extraTsv
assert' "parseCommunityItem Some for extra cols" extraParsed.IsSome ""
assertEqual "extra cols: number" "99" extraParsed.Value.Number

let spaceTsv = "  5  \t  Spaces Title  \t  devuser  \t  repo  \t  https://url  \t  2025-12-01T00:00:00Z  "
let spaceParsed = parseCommunityItem spaceTsv
assertEqual "trimmed number" "5" spaceParsed.Value.Number
assertEqual "trimmed author" "devuser" spaceParsed.Value.Author

let htmlCharTsv = "5\t<script>alert('xss')</script>\tattacker\torg/repo\thttps://x\t2026-01-01T00:00:00Z"
let htmlParsed = parseCommunityItem htmlCharTsv
assertEqual "raw title stored unescaped" "<script>alert('xss')</script>" htmlParsed.Value.Title
assertEqual "escape makes title safe" "&lt;script&gt;alert('xss')&lt;/script&gt;" (escape htmlParsed.Value.Title)

// ----------------------------------------------------------
printfn "\n%s" (bold "11. filterCommunity")
// ----------------------------------------------------------

let makeItem author = { Number = "1"; Title = "t"; Author = author; Repo = "r"; Url = "u"; CreatedAt = "2026-01-01" }
let communityItems = [| makeItem "jsmith"; makeItem "MelbourneDeveloper"; makeItem "melbournedeveloper"; makeItem "MELBOURNEDEVELOPER"; makeItem "notMelbourneDeveloper"; makeItem "contributor99" |]
let filtered = filterCommunity "MelbourneDeveloper" communityItems
assertEqual "filterCommunity removes 3 owner items" 3 filtered.Length
assert' "keeps jsmith" (filtered |> Array.exists (fun i -> i.Author = "jsmith")) ""
assert' "keeps contributor99" (filtered |> Array.exists (fun i -> i.Author = "contributor99")) ""
assert' "keeps notMelbourneDeveloper" (filtered |> Array.exists (fun i -> i.Author = "notMelbourneDeveloper")) ""
assertEqual "filterCommunity empty input" 0 (filterCommunity "x" [||]).Length
assertEqual "filterCommunity all-owner" 0 (filterCommunity "MelbourneDeveloper" [| makeItem "MelbourneDeveloper"; makeItem "melbournedeveloper" |]).Length

// ----------------------------------------------------------
printfn "\n%s" (bold "12. formatCreatedAt")
// ----------------------------------------------------------

assertEqual "formatCreatedAt ISO" "2026-03-01" (formatCreatedAt "2026-03-01T12:00:00Z")
assertEqual "formatCreatedAt exact 10" "2026-03-01" (formatCreatedAt "2026-03-01")
assertEqual "formatCreatedAt short passthrough" "2026" (formatCreatedAt "2026")
assertEqual "formatCreatedAt empty passthrough" "" (formatCreatedAt "")

// ----------------------------------------------------------
printfn "\n%s" (bold "13. run — working directory matters")
// ----------------------------------------------------------

let wdRepo = createTempDir "wd-test"
gitInitWithFile wdRepo "specific.txt" "hello"
assertEqual "run respects working directory" "specific.txt" (run "ls" "specific.txt" wdRepo)

// ----------------------------------------------------------
printfn "\n%s" (bold "14. Sorting — repos sorted by folder modified desc")
// ----------------------------------------------------------

let sortDir = createTempDir "sort-parent"
let sortRepo1 = Path.Combine(sortDir, "older-repo")
Directory.CreateDirectory(sortRepo1) |> ignore
gitInitWithFile sortRepo1 "f.txt" "x"
Directory.SetLastWriteTimeUtc(sortRepo1, DateTime(2020, 1, 1))

let sortRepo2 = Path.Combine(sortDir, "newer-repo")
Directory.CreateDirectory(sortRepo2) |> ignore
gitInitWithFile sortRepo2 "f.txt" "x"
Directory.SetLastWriteTimeUtc(sortRepo2, DateTime(2025, 6, 1))

let sorted = Directory.GetDirectories(sortDir) |> Array.filter isGitRepo |> Array.sortByDescending (fun dir -> Directory.GetLastWriteTimeUtc(dir))
assertEqual "sorted first is newer" "newer-repo" (Path.GetFileName(sorted.[0]))
assertEqual "sorted second is older" "older-repo" (Path.GetFileName(sorted.[1]))

// ----------------------------------------------------------
printfn "\n%s" (bold "15. Truncation — top 20 limit")
// ----------------------------------------------------------

let truncDir = createTempDir "trunc-parent"
for i in 1..25 do
    let d = Path.Combine(truncDir, $"repo-{i:D3}")
    Directory.CreateDirectory(d) |> ignore
    gitInit d

let allTrunc = Directory.GetDirectories(truncDir) |> Array.filter isGitRepo
assertEqual "found 25 repos" 25 allTrunc.Length
let truncated = allTrunc |> Array.sortByDescending (fun dir -> Directory.GetLastWriteTimeUtc(dir)) |> Array.truncate 20
assertEqual "truncated to 20" 20 truncated.Length

// ----------------------------------------------------------
printfn "\n%s" (bold "16. Scan directory — filters non-repos")
// ----------------------------------------------------------

let scanDir = createTempDir "scan-parent"
let repo1 = Path.Combine(scanDir, "repo-aaa")
Directory.CreateDirectory(repo1) |> ignore
gitInitWithFile repo1 "code.txt" "code content"
let repo2 = Path.Combine(scanDir, "repo-bbb")
Directory.CreateDirectory(repo2) |> ignore
gitInitWithFile repo2 "app.txt" "app content"
File.WriteAllText(Path.Combine(repo2, "extra.txt"), "uncommitted")
let repo3 = Path.Combine(scanDir, "not-a-repo")
Directory.CreateDirectory(repo3) |> ignore
File.WriteAllText(Path.Combine(repo3, "random.txt"), "data")

let scannedDirs = Directory.GetDirectories(scanDir) |> Array.filter isGitRepo
assertEqual "scan finds 2 git repos" 2 scannedDirs.Length
assert' "scan excludes non-repo" (scannedDirs |> Array.forall (fun d -> Path.GetFileName(d) <> "not-a-repo")) ""

let repoA = scannedDirs |> Array.find (fun d -> Path.GetFileName(d) = "repo-aaa")
assertEqual "repo-aaa 0 uncommitted" 0 (getModifiedCount repoA)
assertEqual "repo-aaa last edit is today" today (getLastEditDate repoA)
assertEqual "repo-aaa push status" "No upstream" (getPushStatus repoA)

let repoB = scannedDirs |> Array.find (fun d -> Path.GetFileName(d) = "repo-bbb")
assert' "repo-bbb has uncommitted" (getModifiedCount repoB >= 1) $"got {getModifiedCount repoB}"

// Cleanup unit test temp dirs
try Directory.Delete(tempRoot, true) with _ -> ()

// ============================================================
// PART 2: INTEGRATION TEST — generate report from mock repos
// ============================================================

printfn "\n%s" (bold "=== INTEGRATION: Generate report from mock repos ===")
printfn ""

let scriptDir = __SOURCE_DIRECTORY__
let reportOutputPath = Path.Combine(scriptDir, "repo-report.html")

let fixturesDir = Path.Combine(Path.GetTempPath(), "repo-report-integ-" + Guid.NewGuid().ToString("N").[0..7])
Directory.CreateDirectory(fixturesDir) |> ignore
printfn "    Fixtures dir: %s" fixturesDir

let createMockRepo (name: string) (branch: string) (uncommittedFiles: int) =
    let repoDir = Path.Combine(fixturesDir, name)
    Directory.CreateDirectory(repoDir) |> ignore
    runShell (git + " init") repoDir |> ignore
    runShell (git + " config user.email test@test.com") repoDir |> ignore
    runShell (git + " config user.name TestUser") repoDir |> ignore
    File.WriteAllText(Path.Combine(repoDir, "README.md"), "# " + name)
    runShell (git + " add .") repoDir |> ignore
    runShell (git + " commit -m 'initial commit'") repoDir |> ignore
    if branch <> "main" then
        runShell (git + " checkout -b " + branch) repoDir |> ignore
        File.WriteAllText(Path.Combine(repoDir, "feature.txt"), "feature work")
        runShell (git + " add .") repoDir |> ignore
        runShell (git + " commit -m 'feature work'") repoDir |> ignore
    for i in 1..uncommittedFiles do
        File.WriteAllText(Path.Combine(repoDir, sprintf "dirty-%d.txt" i), "uncommitted change " + string i)
    printfn "    Created: %s (branch=%s, dirty=%d)" name branch uncommittedFiles

createMockRepo "alpha-service" "main" 0
createMockRepo "beta-api" "feature/auth" 3
createMockRepo "gamma-client" "main" 1
createMockRepo "delta-lib" "fix/bug-42" 0
createMockRepo "epsilon-tool" "main" 5

// ----------------------------------------------------------
printfn "\n%s" (bold "17. Report generation")
// ----------------------------------------------------------

let reportScript = Path.Combine(scriptDir, "repo-report.fsx")
let genPsi = ProcessStartInfo(fileName = "dotnet", Arguments = "fsi " + reportScript)
genPsi.WorkingDirectory <- scriptDir
genPsi.RedirectStandardOutput <- true
genPsi.RedirectStandardError <- true
genPsi.UseShellExecute <- false
genPsi.CreateNoWindow <- true
genPsi.EnvironmentVariables.["REPO_SCAN_DIR"] <- fixturesDir
genPsi.EnvironmentVariables.["REPORT_OUTPUT_PATH"] <- reportOutputPath
genPsi.EnvironmentVariables.["MAX_REPOS"] <- "20"
genPsi.EnvironmentVariables.["GITHUB_OWNERS"] <- "test-fixture-no-such-owner-xxx"
let genProc = Process.Start(genPsi)
let genStdout = genProc.StandardOutput.ReadToEnd()
let genStderr = genProc.StandardError.ReadToEnd()
genProc.WaitForExit(120000) |> ignore

printfn "    Exit code: %d" genProc.ExitCode
if genStdout.Length > 0 then printfn "    STDOUT:\n%s" genStdout
if genStderr.Length > 0 then printfn "    STDERR:\n%s" genStderr

assert' "report generation exit code 0" (genProc.ExitCode = 0) $"exit code was {genProc.ExitCode}"
assert' "report file exists" (File.Exists reportOutputPath) $"not found at {reportOutputPath}"

if not (File.Exists reportOutputPath) then
    printfn "    FATAL: No report — cannot continue"
    try Directory.Delete(fixturesDir, true) with _ -> ()
    printfn "\n%s" (bold "=== Results ===")
    printfn "  %s" (green $"{passed} passed")
    printfn "  %s" (red $"{failed} failed")
    exit 1

let html = File.ReadAllText(reportOutputPath)

// ----------------------------------------------------------
printfn "\n%s" (bold "18. HTML document structure")
// ----------------------------------------------------------

assert' "HTML is not empty" (html.Length > 500) $"only {html.Length} chars"
assertContains "DOCTYPE" "<!DOCTYPE html>" html
assertContains "html lang" "<html lang=\"en\">" html
assertContains "charset UTF-8" "<meta charset=\"UTF-8\">" html
assertContains "title" "<title>Agent PMO Dashboard</title>" html
assertContains "closing html tag" "</html>" html
assertContains "has body" "<body>" html
assertContains "has style block" "<style>" html
assertContains "has script block" "<script>" html

// ----------------------------------------------------------
printfn "\n%s" (bold "19. Page header")
// ----------------------------------------------------------

assertContains "h1 title" "<h1>Dashboard</h1>" html
assertContains "meta generation line" "Generated:" html
assertContains "repos scanned count" "Repos scanned:" html
assertContains "meta shows 5 repos" "Repos scanned: 5" html

// ----------------------------------------------------------
printfn "\n%s" (bold "20. Table structure — all 11 columns")
// ----------------------------------------------------------

assertContains "has table" "<table>" html
assertContains "has thead" "<thead>" html
assertContains "has tbody" "<tbody>" html
assertContains "col: Repository" ">Repository<" html
assertContains "col: Uncommitted" ">Uncommitted<" html
assertContains "col: Last Commit" ">Last Commit<" html
assertContains "col: Branch" ">Branch<" html
assertContains "col: PR Branch" ">PR Branch<" html
assertContains "col: Push Status" ">Push Status<" html
assertContains "col: Open PR" ">Open PR<" html
assertContains "col: CI" ">CI<" html
assertContains "col: CI Date" ">CI Date<" html
assertContains "col: CI Error" ">CI Error<" html
assertContains "col: Release" ">Release<" html

// Count rows — should be exactly 5
let rowCount = html.Split("<tr>").Length - 1 // -1 for header row split
// thead has 1 <tr>, tbody should have 5
let tbodyStart = html.IndexOf("<tbody>")
let tbodyEnd = html.IndexOf("</tbody>")
let tbodyHtml = html.[tbodyStart..tbodyEnd]
let dataRowCount = tbodyHtml.Split("<tr>").Length - 1
assert' "table has 5 data rows" (dataRowCount = 5) $"got {dataRowCount}"

// ----------------------------------------------------------
printfn "\n%s" (bold "21. All 5 mock repos present")
// ----------------------------------------------------------

assertContains "alpha-service in report" "alpha-service" html
assertContains "beta-api in report" "beta-api" html
assertContains "gamma-client in report" "gamma-client" html
assertContains "delta-lib in report" "delta-lib" html
assertContains "epsilon-tool in report" "epsilon-tool" html
assertNotContains "no other repos leaked in" "not-a-repo" html

// ----------------------------------------------------------
printfn "\n%s" (bold "22. Branches rendered correctly")
// ----------------------------------------------------------

assertContains "main branch in mono span" "class=\"mono\">main<" html
assertContains "feature/auth branch" "feature/auth" html
assertContains "fix/bug-42 branch" "fix/bug-42" html

// ----------------------------------------------------------
printfn "\n%s" (bold "23. Uncommitted counts and CSS classes")
// ----------------------------------------------------------

// alpha-service: 0 dirty (ok), beta-api: 3 (err), gamma-client: 1 (err), delta-lib: 0 (ok), epsilon-tool: 5 (err)
assertContains "ok class for 0 uncommitted" "class=\"ok\">0<" html
assertContains "err class for 3 uncommitted" "class=\"err\">3<" html
assertContains "err class for 1 uncommitted" "class=\"err\">1<" html
assertContains "err class for 5 uncommitted" "class=\"err\">5<" html

// ----------------------------------------------------------
printfn "\n%s" (bold "24. Push status — all show No upstream")
// ----------------------------------------------------------

// Mock repos have no remote, so all should say "No upstream"
assertContains "No upstream status" "No upstream" html
// Should have warn class for no upstream
assertContains "warn class for no upstream" "class=\"warn\">No upstream<" html

// ----------------------------------------------------------
printfn "\n%s" (bold "25. Last commit dates")
// ----------------------------------------------------------

// All repos were just created, so dates should contain today
assertContains "last commit contains today's date" today html

// ----------------------------------------------------------
printfn "\n%s" (bold "26. Tabs — structure")
// ----------------------------------------------------------

assertContains "Repo Status tab button" "data-tab=\"tab-repos\"" html
assertContains "Community PRs tab button" "data-tab=\"tab-prs\"" html
assertContains "Community Issues tab button" "data-tab=\"tab-issues\"" html
assertContains "tab-repos content div" "id=\"tab-repos\"" html
assertContains "tab-prs content div" "id=\"tab-prs\"" html
assertContains "tab-issues content div" "id=\"tab-issues\"" html
assertContains "Repo Status is active by default" "tab-content active\" id=\"tab-repos\"" html
assertContains "PRs tab not active initially" "tab-content\" id=\"tab-prs\"" html
assertContains "Issues tab not active initially" "tab-content\" id=\"tab-issues\"" html
assertContains "Repo Status label" ">Repo Status<" html
assertContains "Community PRs label" "Community PRs" html
assertContains "Community Issues label" "Community Issues" html

// ----------------------------------------------------------
printfn "\n%s" (bold "27. Tab counts — PRs and Issues show (0)")
// ----------------------------------------------------------

assertContains "PR count is 0" "Community PRs (0)" html
assertContains "Issues count is 0" "Community Issues (0)" html

// ----------------------------------------------------------
printfn "\n%s" (bold "28. Community sections — empty state")
// ----------------------------------------------------------

assertContains "no community PRs message" "No community PRs found" html
assertContains "no community issues message" "No community issues found" html

// ----------------------------------------------------------
printfn "\n%s" (bold "29. JavaScript functionality")
// ----------------------------------------------------------

assertContains "showTab function" "function showTab" html
assertContains "setInterval for auto-refresh" "setInterval" html
assertContains "copyLog function" "copyLog" html
assertContains "Escape key handler" "Escape" html
assertContains "modal-overlay CSS class" ".modal-overlay" html
assertContains "modal-overlay.active check" "modal-overlay.active" html
assertNotContains "no meta http-equiv refresh" "http-equiv=\"refresh\"" html
assertContains "clipboard API usage" "navigator.clipboard" html
assertContains "location.reload in interval" "location.reload" html
assertContains "hash-based tab persistence" "location.hash" html

// ----------------------------------------------------------
printfn "\n%s" (bold "30. CSS classes present")
// ----------------------------------------------------------

assertContains "ok class defined" ".ok {" html
assertContains "err class defined" ".err {" html
assertContains "warn class defined" ".warn {" html
assertContains "mono class defined" ".mono {" html
assertContains "ci-err class defined" ".ci-err {" html
assertContains "modal class defined" ".modal {" html
assertContains "modal-overlay class defined" ".modal-overlay {" html
assertContains "tab-btn class defined" ".tab-btn {" html
assertContains "tab-content class defined" ".tab-content {" html
assertContains "filter-bar class defined" ".filter-bar {" html

// ----------------------------------------------------------
printfn "\n%s" (bold "31. No CI/PR data for mock repos (no remotes)")
// ----------------------------------------------------------

// Mock repos have no GitHub remote, so CI/PR columns should be empty
assertNotContains "no FAILURE status (no CI data)" ">FAILURE<" html
assertNotContains "no SUCCESS status (no CI data)" ">SUCCESS<" html
// PR columns should all be empty
assertNotContains "no PR links" "github.com" html

// ============================================================
// CLEANUP
// ============================================================

printfn "\n=== CLEANUP ==="
try Directory.Delete(fixturesDir, true)
    printfn "    Deleted fixtures dir"
with ex -> printfn "    Warning: %s" ex.Message

// ============================================================
// RESULTS
// ============================================================

printfn ""
printfn "%s" (bold "=== Results ===")
printfn "  %s" (green $"{passed} passed")
if failed > 0 then
    printfn "  %s" (red $"{failed} failed")
    printfn ""
    for e in errors do
        printfn "  %s %s" (red "x") e
    printfn ""
    exit 1
else
    printfn "  %s" (green "All tests passed!")
    printfn ""
    exit 0
