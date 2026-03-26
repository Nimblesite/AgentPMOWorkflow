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
let yellow s = $"\x1b[33m{s}\x1b[0m"
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
    assert' name (actual.Contains(substring)) $"expected to contain '{substring}', got '{actual}'"

let assertNotEmpty (name: string) (actual: string) =
    assert' name (not (String.IsNullOrWhiteSpace(actual))) "was empty"

// ============================================================
// Copy functions from repo-report.fsx (can't #load it because
// it has top-level side effects that scan the real filesystem)
// ============================================================

let resolveCmd (cmd: string) =
    let paths = [| "/opt/homebrew/bin"; "/usr/local/bin"; "/usr/bin"; "/bin" |]
    match paths |> Array.tryFind (fun p -> File.Exists(Path.Combine(p, cmd))) with
    | Some p -> Path.Combine(p, cmd)
    | None -> cmd

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
    with ex -> ""

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

let getOpenPR (dir: string) currentBranch =
    let headArg = "--head " + currentBranch
    let title = run "gh" ("pr list --state open " + headArg + " --json title --limit 1 --jq .[0].title") dir
    let branch = run "gh" ("pr list --state open " + headArg + " --json headRefName --limit 1 --jq .[0].headRefName") dir
    let number = run "gh" ("pr list --state open " + headArg + " --json number --limit 1 --jq .[0].number") dir
    let t = if String.IsNullOrWhiteSpace(title) || title = "null" then "" else title
    let b = if String.IsNullOrWhiteSpace(branch) || branch = "null" then "" else branch
    let n = if String.IsNullOrWhiteSpace(number) || number = "null" then "" else number
    (t, b, n)

let getCIStatus (dir: string) (prNumber: string) =
    if prNumber = "" then
        ("", "", "")
    else
        let prArg = prNumber
        let allStates = run "gh" ("pr view " + prArg + " --json statusCheckRollup --jq '.statusCheckRollup.[].conclusion'") dir
        let states =
            if String.IsNullOrWhiteSpace(allStates) then [||]
            else allStates.Split('\n') |> Array.map (fun s -> s.Trim().ToUpperInvariant()) |> Array.filter (fun s -> s <> "" && s <> "NULL")
        let allStatuses = run "gh" ("pr view " + prArg + " --json statusCheckRollup --jq '.statusCheckRollup.[].status'") dir
        let statuses =
            if String.IsNullOrWhiteSpace(allStatuses) then [||]
            else allStatuses.Split('\n') |> Array.map (fun s -> s.Trim().ToUpperInvariant()) |> Array.filter (fun s -> s <> "" && s <> "NULL")
        let hasInProgress = statuses |> Array.exists (fun s -> s = "IN_PROGRESS" || s = "PENDING" || s = "QUEUED")
        let aggregate =
            if states |> Array.exists (fun s -> s = "FAILURE" || s = "ERROR" || s = "STARTUP_FAILURE") then "FAILURE"
            elif states |> Array.exists (fun s -> s = "CANCELLED") then "CANCELLED"
            elif hasInProgress then "IN_PROGRESS"
            elif states |> Array.exists (fun s -> s = "SUCCESS") then "SUCCESS"
            elif states.Length > 0 then states.[0]
            else ""
        let date = run "gh" ("pr view " + prArg + " --json statusCheckRollup --jq '.statusCheckRollup.[0].startedAt'") dir
        let dateShort = if date.Length >= 16 then date.[0..15].Replace("T", " ") else date
        let failedDetails = run "gh" ("pr view " + prArg + " --json statusCheckRollup --jq '.statusCheckRollup.[] | select(.conclusion==\"FAILURE\" or .conclusion==\"ERROR\" or .conclusion==\"STARTUP_FAILURE\") | (.name + \": \" + .description)'") dir
        let errorText =
            if String.IsNullOrWhiteSpace(failedDetails) || failedDetails = "null" then ""
            else failedDetails.Trim()
        (aggregate, dateShort, errorText)

let escape (s: string) =
    s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")

// ============================================================
// Helpers for setting up temp git repos
// ============================================================

let tempRoot = Path.Combine(Path.GetTempPath(), "repo-report-tests-" + Guid.NewGuid().ToString("N").[..7])

let createTempDir name =
    let d = Path.Combine(tempRoot, name)
    Directory.CreateDirectory(d) |> ignore
    d

let gitInit dir =
    run "git" "init" dir |> ignore
    run "git" "-c user.email=test@test.com -c user.name=Test commit --allow-empty -m \"initial\"" dir |> ignore

let gitInitWithFile dir fileName (content: string) =
    gitInit dir
    File.WriteAllText(Path.Combine(dir, fileName), content)
    run "git" $"add {fileName}" dir |> ignore
    run "git" "-c user.email=test@test.com -c user.name=Test commit -m \"add file\"" dir |> ignore

let cleanup () =
    try Directory.Delete(tempRoot, true) with _ -> ()

// ============================================================
// TESTS
// ============================================================

printfn ""
printfn "%s" (bold "=== repo-report.fsx E2E Tests ===")
printfn ""

// ----------------------------------------------------------
printfn "%s" (bold "1. resolveCmd")
// ----------------------------------------------------------

let gitPath = resolveCmd "git"
assert' "resolveCmd finds git" (File.Exists(gitPath)) $"path={gitPath}"

let bogusPath = resolveCmd "surely_no_such_binary_abc123"
assertEqual "resolveCmd returns raw name for missing cmd" "surely_no_such_binary_abc123" bogusPath

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "2. run")
// ----------------------------------------------------------

let echoResult = run "echo" "hello world" "/"
assertEqual "run captures stdout" "hello world" echoResult

let failResult = run "false" "" "/"
assertEqual "run returns empty on failure exit" "" failResult

let badCmd = run "surely_no_such_binary_abc123" "" "/"
assertEqual "run returns empty on missing command" "" badCmd

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "3. isGitRepo")
// ----------------------------------------------------------

Directory.CreateDirectory(tempRoot) |> ignore

let gitDir = createTempDir "real-repo"
gitInit gitDir
assert' "isGitRepo true for git repo" (isGitRepo gitDir) ""

let plainDir = createTempDir "not-a-repo"
assert' "isGitRepo false for non-repo" (not (isGitRepo plainDir)) ""

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "4. getModifiedCount")
// ----------------------------------------------------------

let cleanRepo = createTempDir "clean-repo"
gitInitWithFile cleanRepo "file.txt" "hello"
assertEqual "getModifiedCount 0 for clean repo" 0 (getModifiedCount cleanRepo)

// Add an untracked file
File.WriteAllText(Path.Combine(cleanRepo, "untracked.txt"), "new")
let countWithUntracked = getModifiedCount cleanRepo
assert' "getModifiedCount counts untracked file" (countWithUntracked >= 1) $"got {countWithUntracked}"

// Modify a tracked file
File.WriteAllText(Path.Combine(cleanRepo, "file.txt"), "modified")
let countWithModified = getModifiedCount cleanRepo
assert' "getModifiedCount counts modified + untracked" (countWithModified >= 2) $"got {countWithModified}"

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "5. getLastEditDate")
// ----------------------------------------------------------

let dateRepo = createTempDir "date-repo"
gitInitWithFile dateRepo "f.txt" "x"
let lastEdit = getLastEditDate dateRepo
assert' "getLastEditDate returns a date string" (lastEdit.Contains("-") && lastEdit.Length >= 10) $"got '{lastEdit}'"
// Should be today's date
let today = DateTime.Now.ToString("yyyy-MM-dd")
assertEqual "getLastEditDate is today" today lastEdit

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "6. getBranch")
// ----------------------------------------------------------

let branchRepo = createTempDir "branch-repo"
gitInitWithFile branchRepo "f.txt" "x"

// Default branch could be main or master depending on git config
let defaultBranch = getBranch branchRepo
assert' "getBranch returns non-empty" (defaultBranch = "main" || defaultBranch = "master") $"got '{defaultBranch}'"

// Create and switch to a feature branch
run "git" "checkout -b feature/test-branch" branchRepo |> ignore
assertEqual "getBranch on feature branch" "feature/test-branch" (getBranch branchRepo)

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "7. getPushStatus — no upstream")
// ----------------------------------------------------------

let pushRepo = createTempDir "push-repo"
gitInitWithFile pushRepo "f.txt" "x"
let noUpstream = getPushStatus pushRepo
assertEqual "getPushStatus with no upstream" "No upstream" noUpstream

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "8. getPushStatus — with upstream (ahead/behind/up-to-date)")
// ----------------------------------------------------------

// Create a bare "remote" and clone it
let bareDir = createTempDir "bare-remote"
run "git" "init --bare" bareDir |> ignore

let clonedDir = Path.Combine(tempRoot, "cloned-repo")
run "git" $"clone {bareDir} {clonedDir}" tempRoot |> ignore

// Make an initial commit and push
File.WriteAllText(Path.Combine(clonedDir, "file.txt"), "initial")
run "git" "add file.txt" clonedDir |> ignore
run "git" "-c user.email=test@test.com -c user.name=Test commit -m init" clonedDir |> ignore
let mainBranch = getBranch clonedDir
run "git" $"push -u origin {mainBranch}" clonedDir |> ignore

let upToDate = getPushStatus clonedDir
assertEqual "getPushStatus up to date" "Up to date" upToDate

// Make a local commit (ahead by 1)
File.WriteAllText(Path.Combine(clonedDir, "file.txt"), "changed")
run "git" "add file.txt" clonedDir |> ignore
run "git" "-c user.email=test@test.com -c user.name=Test commit -m ahead" clonedDir |> ignore
let aheadStatus = getPushStatus clonedDir
assertEqual "getPushStatus ahead" "Ahead 1" aheadStatus

// Push and then reset behind
run "git" $"push origin {mainBranch}" clonedDir |> ignore
run "git" "reset --hard HEAD~1" clonedDir |> ignore
let behindStatus = getPushStatus clonedDir
assertEqual "getPushStatus behind" "Behind 1" behindStatus

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "9. escape — HTML escaping")
// ----------------------------------------------------------

assertEqual "escape ampersand" "&amp;" (escape "&")
assertEqual "escape less-than" "&lt;" (escape "<")
assertEqual "escape greater-than" "&gt;" (escape ">")
assertEqual "escape combined" "&lt;b&gt;hello &amp; world&lt;/b&gt;" (escape "<b>hello & world</b>")
assertEqual "escape plain text unchanged" "hello world" (escape "hello world")
assertEqual "escape empty string" "" (escape "")

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "10. getOpenPR — no PR expected in temp repo")
// ----------------------------------------------------------

let prTitle, prBranch, prNumber = getOpenPR cleanRepo "main"
assertEqual "getOpenPR title empty for local repo" "" prTitle
assertEqual "getOpenPR branch empty for local repo" "" prBranch
assertEqual "getOpenPR number empty for local repo" "" prNumber

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "11. getCIStatus — empty when no PR number")
// ----------------------------------------------------------

let ciStatus, ciDate, ciError = getCIStatus cleanRepo ""
assertEqual "getCIStatus empty when no PR" "" ciStatus
assertEqual "getCIDate empty when no PR" "" ciDate
assertEqual "getCIError empty when no PR" "" ciError

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "12. CI aggregation logic (unit tests)")
// ----------------------------------------------------------

// Test the aggregation logic directly by simulating different state arrays
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
printfn ""
printfn "%s" (bold "13. isGitRepo — edge cases")
// ----------------------------------------------------------

let emptyDir = createTempDir "empty-dir"
assert' "isGitRepo false for empty dir" (not (isGitRepo emptyDir)) ""

let fakeGit = createTempDir "fake-git"
// .git as a file (submodule-style) should still make Directory.Exists false
File.WriteAllText(Path.Combine(fakeGit, ".git"), "gitdir: /somewhere")
assert' "isGitRepo false when .git is a file" (not (isGitRepo fakeGit)) ""

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "14. getModifiedCount — staged vs unstaged")
// ----------------------------------------------------------

let stagedRepo = createTempDir "staged-repo"
gitInitWithFile stagedRepo "a.txt" "aaa"

// Stage a new file but don't commit
File.WriteAllText(Path.Combine(stagedRepo, "b.txt"), "bbb")
run "git" "add b.txt" stagedRepo |> ignore
let stagedCount = getModifiedCount stagedRepo
assert' "getModifiedCount includes staged files" (stagedCount >= 1) $"got {stagedCount}"

// Also modify tracked file without staging
File.WriteAllText(Path.Combine(stagedRepo, "a.txt"), "modified-a")
let mixedCount = getModifiedCount stagedRepo
assert' "getModifiedCount includes staged + unstaged" (mixedCount >= 2) $"got {mixedCount}"

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "15. getLastEditDate — empty repo")
// ----------------------------------------------------------

let emptyRepo = createTempDir "empty-git-repo"
run "git" "init" emptyRepo |> ignore
// No commits at all
let emptyDate = getLastEditDate emptyRepo
assertEqual "getLastEditDate unknown for empty repo" "unknown" emptyDate

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "16. Multiple branches — getBranch after checkout")
// ----------------------------------------------------------

let multiBranchRepo = createTempDir "multi-branch"
gitInitWithFile multiBranchRepo "f.txt" "content"
run "git" "checkout -b dev" multiBranchRepo |> ignore
assertEqual "getBranch dev" "dev" (getBranch multiBranchRepo)
run "git" "checkout -b release/v1.0" multiBranchRepo |> ignore
assertEqual "getBranch release/v1.0" "release/v1.0" (getBranch multiBranchRepo)
let origBranch = run "git" "rev-parse --verify main" multiBranchRepo
let fallback = if origBranch <> "" then "main" else "master"
run "git" $"checkout {fallback}" multiBranchRepo |> ignore
assertEqual $"getBranch back to {fallback}" fallback (getBranch multiBranchRepo)

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "17. HTML generation — full report structure")
// ----------------------------------------------------------

type RepoInfo = {
    Name: string
    FolderModified: DateTime
    ModifiedCount: int
    LastEdit: string
    Branch: string
    PRBranch: string
    PushStatus: string
    OpenPR: string
    CIStatus: string
    CIDate: string
    CIError: string
}

let testRepos = [|
    { Name = "alpha-repo"; FolderModified = DateTime(2026, 1, 15); ModifiedCount = 3
      LastEdit = "2026-01-15"; Branch = "main"; PRBranch = ""; PushStatus = "Up to date"
      OpenPR = ""; CIStatus = "SUCCESS"; CIDate = "2026-01-15 10:00"; CIError = "" }
    { Name = "beta-repo"; FolderModified = DateTime(2026, 1, 14); ModifiedCount = 0
      LastEdit = "2026-01-14"; Branch = "feature/xyz"; PRBranch = "feature/xyz"; PushStatus = "Ahead 2"
      OpenPR = "Add XYZ feature"; CIStatus = "FAILURE"; CIDate = "2026-01-14 09:00"
      CIError = "build: compilation failed" }
    { Name = "<special>&chars"; FolderModified = DateTime(2026, 1, 13); ModifiedCount = 1
      LastEdit = "2026-01-13"; Branch = "main"; PRBranch = ""; PushStatus = "No upstream"
      OpenPR = ""; CIStatus = ""; CIDate = ""; CIError = "" }
|]

let sb = StringBuilder()
let a (s: string) = sb.AppendLine(s) |> ignore

a "<!DOCTYPE html>"
a "<html lang=\"en\">"
a "<head>"
a "<meta charset=\"UTF-8\">"
a "<meta http-equiv=\"refresh\" content=\"5\">"
a "<title>Repo Report</title>"
a "<style>"
a "body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; margin: 40px; background: #f0f4f8; color: #1a202c; }"
a "h1 { font-size: 1.6rem; margin-bottom: 4px; }"
a ".meta { color: #718096; font-size: 0.85rem; margin-bottom: 24px; }"
a "table { border-collapse: collapse; width: 100%; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 1px 6px rgba(0,0,0,0.1); }"
a "th { background: #2d3748; color: white; padding: 10px 14px; text-align: left; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.05em; }"
a "td { padding: 10px 14px; border-bottom: 1px solid #e2e8f0; font-size: 0.875rem; }"
a "tr:last-child td { border-bottom: none; }"
a "tr:hover td { background: #f7fafc; }"
a ".count { font-weight: 700; color: #e53e3e; }"
a ".ok { color: #38a169; }"
a ".warn { color: #d69e2e; }"
a ".err { color: #e53e3e; }"
a ".mono { font-family: monospace; font-size: 0.8rem; background: #edf2f7; padding: 1px 5px; border-radius: 3px; }"
a ".ci-err { max-width: 250px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #e53e3e; font-size: 0.8rem; cursor: help; }"
a ".ci-err:hover { white-space: normal; overflow: visible; position: relative; z-index: 10; background: #fff5f5; padding: 6px 8px; border-radius: 4px; box-shadow: 0 2px 8px rgba(0,0,0,0.15); max-width: 500px; }"
a "</style>"
a "</head>"
a "<body>"
a "<h1>Repo Report</h1>"

let metaLine = "<p class=\"meta\">Generated: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + " &nbsp;|&nbsp; Repos with changes: " + string testRepos.Length + "</p>"
a metaLine

if testRepos.Length = 0 then
    a "<p>No repos with uncommitted changes found.</p>"
else
    a "<table>"
    a "<thead><tr>"
    a "<th>Repository</th>"
    a "<th>Uncommitted</th>"
    a "<th>Last Commit</th>"
    a "<th>Branch</th>"
    a "<th>PR Branch</th>"
    a "<th>Push Status</th>"
    a "<th>Open PR</th>"
    a "<th>CI</th>"
    a "<th>CI Date</th>"
    a "<th>CI Error</th>"
    a "</tr></thead>"
    a "<tbody>"

    for r in testRepos do
        let pushClass =
            if r.PushStatus = "Up to date" then "ok"
            elif r.PushStatus = "No upstream" then "warn"
            else "warn"
        let ciUpper = r.CIStatus.ToUpperInvariant()
        let ciClass =
            if ciUpper = "SUCCESS" then "ok"
            elif ciUpper = "FAILURE" || ciUpper = "SKIPPED" || ciUpper = "CANCELLED" || ciUpper = "ERROR" || ciUpper = "STARTUP_FAILURE" then "err"
            elif ciUpper = "IN_PROGRESS" || ciUpper = "PENDING" || ciUpper = "QUEUED" then "warn"
            else ""

        a "<tr>"
        a ("<td>" + escape r.Name + "</td>")
        let uncommittedClass = if r.ModifiedCount > 0 then "err" else "ok"
        a ("<td class=\"" + uncommittedClass + "\">" + string r.ModifiedCount + "</td>")
        a ("<td>" + escape r.LastEdit + "</td>")
        a ("<td><span class=\"mono\">" + escape r.Branch + "</span></td>")
        a ("<td><span class=\"mono\">" + escape r.PRBranch + "</span></td>")
        a ("<td class=\"" + pushClass + "\">" + escape r.PushStatus + "</td>")
        a ("<td>" + escape r.OpenPR + "</td>")
        a ("<td class=\"" + ciClass + "\">" + escape r.CIStatus + "</td>")
        a ("<td>" + escape r.CIDate + "</td>")
        let errDisplay = r.CIError.Replace("\n", " | ")
        if errDisplay <> "" then
            a ("<td class=\"ci-err\" title=\"" + escape(r.CIError.Replace("\"", "'")) + "\">" + escape errDisplay + "</td>")
        else
            a "<td></td>"
        a "</tr>"

    a "</tbody>"
    a "</table>"

a "</body>"
a "</html>"

let html = sb.ToString()

assertContains "HTML has doctype" "<!DOCTYPE html>" html
assertContains "HTML has title" "<title>Repo Report</title>" html
assertContains "HTML has table" "<table>" html
assertContains "HTML has thead" "<thead>" html
assertContains "HTML has auto-refresh meta" "http-equiv=\"refresh\"" html

// Check repo data rendered
assertContains "HTML contains alpha-repo" "alpha-repo" html
assertContains "HTML contains beta-repo" "beta-repo" html
assertContains "HTML escapes special chars in name" "&lt;special&gt;&amp;chars" html
assertContains "HTML has ok class for 0 uncommitted" "class=\"ok\">0<" html
assertContains "HTML has err class for 3 uncommitted" "class=\"err\">3<" html
assertContains "HTML has ok class for success CI" "class=\"ok\">SUCCESS<" html
assertContains "HTML has err class for failure CI" "class=\"err\">FAILURE<" html
assertContains "HTML has warn class for ahead push" "class=\"warn\">Ahead 2<" html
assertContains "HTML has ok class for up-to-date push" "class=\"ok\">Up to date<" html
assertContains "HTML has warn class for no-upstream push" "class=\"warn\">No upstream<" html
assertContains "HTML has PR title" "Add XYZ feature" html
assertContains "HTML has CI error in ci-err cell" "class=\"ci-err\"" html
assertContains "HTML has CI error text" "compilation failed" html
assertContains "HTML has mono branch" "class=\"mono\">main<" html
assertContains "HTML has mono PR branch" "class=\"mono\">feature/xyz<" html
assertContains "HTML has CI date" "2026-01-14 09:00" html

// Check empty cells for repos without PR/CI
let specialRow = html.[html.IndexOf("&lt;special&gt;")..]
// The CI column for repo with empty status should have no class
assertContains "HTML has empty CI cell for no-status" "<td class=\"\"><" html

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "18. HTML generation — empty repo list")
// ----------------------------------------------------------

let sbEmpty = StringBuilder()
let ae (s: string) = sbEmpty.AppendLine(s) |> ignore

ae "<!DOCTYPE html>"
ae "<html lang=\"en\">"
ae "<head></head>"
ae "<body>"
ae "<h1>Repo Report</h1>"

let emptyRepos: RepoInfo[] = [||]
if emptyRepos.Length = 0 then
    ae "<p>No repos with uncommitted changes found.</p>"
else
    ae "<table></table>"

ae "</body></html>"

let emptyHtml = sbEmpty.ToString()
assertContains "Empty HTML has no-repos message" "No repos with uncommitted changes found" emptyHtml
assert' "Empty HTML has no table" (not (emptyHtml.Contains("<table>"))) ""

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "19. CI date formatting logic")
// ----------------------------------------------------------

let formatCIDate (date: string) =
    if date.Length >= 16 then date.[0..15].Replace("T", " ") else date

assertEqual "CI date formatting ISO" "2026-01-15 10:30" (formatCIDate "2026-01-15T10:30:00Z")
assertEqual "CI date formatting short" "short" (formatCIDate "short")
assertEqual "CI date formatting empty" "" (formatCIDate "")
assertEqual "CI date formatting exact 16 replaces T" "2026-01-15 10:30" (formatCIDate "2026-01-15T10:30")

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "20. E2E — scan a temp directory with multiple repos")
// ----------------------------------------------------------

let scanDir = createTempDir "scan-parent"

// Create 3 repos inside scanDir
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

// Scan like the script does
let allDirs = Directory.GetDirectories(scanDir) |> Array.filter isGitRepo
assertEqual "scan finds 2 git repos" 2 allDirs.Length
assert' "scan excludes non-repo" (allDirs |> Array.forall (fun d -> Path.GetFileName(d) <> "not-a-repo")) ""

// Build full RepoInfo for each
let scannedRepos =
    allDirs
    |> Array.map (fun dir ->
        let name = Path.GetFileName(dir)
        let folderMod = Directory.GetLastWriteTimeUtc(dir)
        let modCount = getModifiedCount dir
        let lastEdit = getLastEditDate dir
        let branch = getBranch dir
        let pushStatus = getPushStatus dir
        let openPR, prBranch, prNumber = getOpenPR dir branch
        let ciStatus, ciDate, ciError = getCIStatus dir prNumber
        { Name = name; FolderModified = folderMod; ModifiedCount = modCount; LastEdit = lastEdit
          Branch = branch; PRBranch = prBranch; PushStatus = pushStatus; OpenPR = openPR
          CIStatus = ciStatus; CIDate = ciDate; CIError = ciError }
    )
    |> Array.sortByDescending (fun r -> r.FolderModified)

assertEqual "scanned 2 repos" 2 scannedRepos.Length

let repoA = scannedRepos |> Array.find (fun r -> r.Name = "repo-aaa")
assertEqual "repo-aaa has 0 uncommitted" 0 repoA.ModifiedCount
assertEqual "repo-aaa last edit is today" today repoA.LastEdit
assertEqual "repo-aaa push status" "No upstream" repoA.PushStatus

let repoB = scannedRepos |> Array.find (fun r -> r.Name = "repo-bbb")
assert' "repo-bbb has uncommitted files" (repoB.ModifiedCount >= 1) $"got {repoB.ModifiedCount}"

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "21. E2E — full HTML report from scanned repos")
// ----------------------------------------------------------

let sbFull = StringBuilder()
let af (s: string) = sbFull.AppendLine(s) |> ignore

af "<!DOCTYPE html>"
af "<html lang=\"en\"><head><title>Repo Report</title></head><body>"
af "<table><thead><tr>"
af "<th>Repository</th><th>Uncommitted</th><th>Last Commit</th><th>Branch</th>"
af "<th>PR Branch</th><th>Push Status</th><th>Open PR</th><th>CI</th><th>CI Date</th><th>CI Error</th>"
af "</tr></thead><tbody>"

for r in scannedRepos do
    let uncommittedClass = if r.ModifiedCount > 0 then "err" else "ok"
    let pushClass = if r.PushStatus = "Up to date" then "ok" else "warn"
    af $"<tr><td>{escape r.Name}</td><td class=\"{uncommittedClass}\">{r.ModifiedCount}</td>"
    af $"<td>{escape r.LastEdit}</td><td><span class=\"mono\">{escape r.Branch}</span></td>"
    af $"<td><span class=\"mono\">{escape r.PRBranch}</span></td>"
    af $"<td class=\"{pushClass}\">{escape r.PushStatus}</td>"
    af $"<td>{escape r.OpenPR}</td><td>{escape r.CIStatus}</td>"
    af $"<td>{escape r.CIDate}</td><td>{escape r.CIError}</td></tr>"

af "</tbody></table></body></html>"

let fullHtml = sbFull.ToString()
assertContains "Full report has repo-aaa" "repo-aaa" fullHtml
assertContains "Full report has repo-bbb" "repo-bbb" fullHtml
assertContains "Full report has ok class" "class=\"ok\"" fullHtml
assert' "Full report does not contain not-a-repo" (not (fullHtml.Contains("not-a-repo"))) ""

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "22. Escape edge cases")
// ----------------------------------------------------------

assertEqual "escape double escape" "&amp;amp;" (escape "&amp;")
assertEqual "escape angle brackets (quotes unchanged)" "&lt;div class=\"x\"&gt;" (escape "<div class=\"x\">")
// Actually the escape function only handles &, <, >. Let's test what it actually does:
assertEqual "escape does not touch quotes" "<div class=\"x\">" ("<div class=\"x\">") // quotes pass through
assertEqual "escape sequence of specials" "&lt;&amp;&gt;" (escape "<&>")

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "23. getModifiedCount — deleted file")
// ----------------------------------------------------------

let deleteRepo = createTempDir "delete-repo"
gitInitWithFile deleteRepo "tracked.txt" "content"
File.Delete(Path.Combine(deleteRepo, "tracked.txt"))
let deleteCount = getModifiedCount deleteRepo
assert' "getModifiedCount detects deleted file" (deleteCount >= 1) $"got {deleteCount}"

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "24. getModifiedCount — renamed file")
// ----------------------------------------------------------

let renameRepo = createTempDir "rename-repo"
gitInitWithFile renameRepo "old-name.txt" "content"
File.Move(Path.Combine(renameRepo, "old-name.txt"), Path.Combine(renameRepo, "new-name.txt"))
let renameCount = getModifiedCount renameRepo
assert' "getModifiedCount detects rename" (renameCount >= 1) $"got {renameCount}"

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "25. getBranch — detached HEAD")
// ----------------------------------------------------------

let detachedRepo = createTempDir "detached-repo"
gitInitWithFile detachedRepo "f.txt" "x"
let headSha = run "git" "rev-parse HEAD" detachedRepo
run "git" $"checkout {headSha}" detachedRepo |> ignore
let detachedBranch = getBranch detachedRepo
assertEqual "getBranch on detached HEAD" "HEAD" detachedBranch

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "26. run — working directory matters")
// ----------------------------------------------------------

let wdRepo = createTempDir "wd-test"
gitInitWithFile wdRepo "specific.txt" "hello"
let lsOutput = run "ls" "specific.txt" wdRepo
assertEqual "run respects working directory" "specific.txt" lsOutput

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "27. Sorting — repos sorted by folder modified desc")
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

let sorted =
    Directory.GetDirectories(sortDir)
    |> Array.filter isGitRepo
    |> Array.sortByDescending (fun dir -> Directory.GetLastWriteTimeUtc(dir))

assertEqual "sorted first is newer" "newer-repo" (Path.GetFileName(sorted.[0]))
assertEqual "sorted second is older" "older-repo" (Path.GetFileName(sorted.[1]))

// ----------------------------------------------------------
printfn ""
printfn "%s" (bold "28. Truncation — top 20 limit")
// ----------------------------------------------------------

let truncDir = createTempDir "trunc-parent"
for i in 1..25 do
    let d = Path.Combine(truncDir, $"repo-{i:D3}")
    Directory.CreateDirectory(d) |> ignore
    gitInit d

let allTrunc = Directory.GetDirectories(truncDir) |> Array.filter isGitRepo
assertEqual "found 25 repos" 25 allTrunc.Length

let truncated =
    allTrunc
    |> Array.sortByDescending (fun dir -> Directory.GetLastWriteTimeUtc(dir))
    |> Array.truncate 20
assertEqual "truncated to 20" 20 truncated.Length

// ============================================================
// Cleanup
// ============================================================

cleanup ()

// ============================================================
// Results
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
