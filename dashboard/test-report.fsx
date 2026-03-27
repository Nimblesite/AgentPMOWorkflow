// Tests for repo-report.fsx — deterministic fixture-based tests
// Creates mock git repos, generates the report, validates the HTML.
// Run: dotnet fsi test-report.fsx

open System
open System.IO
open System.Diagnostics

let mutable passed = 0
let mutable failed = 0

let assert_eq (name: string) expected actual =
    if expected = actual then
        passed <- passed + 1
        printfn "  PASS: %s" name
    else
        failed <- failed + 1
        printfn "  FAIL: %s" name
        printfn "    Expected: %A" expected
        printfn "    Actual:   %A" actual

let assert_true (name: string) (cond: bool) =
    if cond then
        passed <- passed + 1
        printfn "  PASS: %s" name
    else
        failed <- failed + 1
        printfn "  FAIL: %s (expected true)" name

let assert_contains (name: string) (haystack: string) (needle: string) =
    if haystack.Contains(needle) then
        passed <- passed + 1
        printfn "  PASS: %s" name
    else
        failed <- failed + 1
        printfn "  FAIL: %s" name
        printfn "    '%s' not found in output" needle

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
        let stderr = p.StandardError.ReadToEnd()
        p.WaitForExit(30000) |> ignore
        try File.Delete(tmpFile) with _ -> ()
        if p.ExitCode <> 0 && stderr <> "" then
            eprintfn "    [stderr] %s" (stderr.Trim())
        output.Trim()
    with ex ->
        eprintfn "    [EXCEPTION] %s" ex.Message
        ""

let run cmd args workDir =
    runShell (resolveCmd cmd + " " + args) workDir

let scriptDir = __SOURCE_DIRECTORY__
let reportOutputPath = Path.Combine(scriptDir, "repo-report.html")

// ============================================================
// CREATE MOCK GIT REPOS IN A TEMP DIRECTORY
// ============================================================
printfn "\n=== SETUP: Creating mock git repos ==="

let fixturesDir = Path.Combine(Path.GetTempPath(), "repo-report-test-" + Guid.NewGuid().ToString("N").[0..7])
Directory.CreateDirectory(fixturesDir) |> ignore
printfn "    Fixtures dir: %s" fixturesDir

let git = resolveCmd "git"

let createMockRepo (name: string) (branch: string) (uncommittedFiles: int) (aheadCount: int) =
    let repoDir = Path.Combine(fixturesDir, name)
    Directory.CreateDirectory(repoDir) |> ignore
    // Init and configure
    runShell (git + " init") repoDir |> ignore
    runShell (git + " config user.email test@test.com") repoDir |> ignore
    runShell (git + " config user.name TestUser") repoDir |> ignore
    // Create initial commit
    File.WriteAllText(Path.Combine(repoDir, "README.md"), "# " + name)
    runShell (git + " add .") repoDir |> ignore
    runShell (git + " commit -m 'initial commit'") repoDir |> ignore
    // Switch to branch if not main
    if branch <> "main" then
        runShell (git + " checkout -b " + branch) repoDir |> ignore
        File.WriteAllText(Path.Combine(repoDir, "feature.txt"), "feature work")
        runShell (git + " add .") repoDir |> ignore
        runShell (git + " commit -m 'feature work'") repoDir |> ignore
    // Add uncommitted files
    for i in 1..uncommittedFiles do
        File.WriteAllText(Path.Combine(repoDir, sprintf "dirty-%d.txt" i), "uncommitted change " + string i)
    printfn "    Created: %s (branch=%s, dirty=%d)" name branch uncommittedFiles

// Create repos with various states
createMockRepo "alpha-service" "main" 0 0        // clean, on main
createMockRepo "beta-api" "feature/auth" 3 0      // dirty, on feature branch
createMockRepo "gamma-client" "main" 1 0          // 1 uncommitted file
createMockRepo "delta-lib" "fix/bug-42" 0 0       // clean, on fix branch
createMockRepo "epsilon-tool" "main" 5 0          // very dirty

printfn "    Created 5 mock repos in %s" fixturesDir

// ============================================================
// GENERATE THE REPORT
// ============================================================
printfn "\n=== GENERATING REPORT ==="

let reportScript = Path.Combine(scriptDir, "repo-report.fsx")
let genPsi = ProcessStartInfo(fileName = "dotnet", Arguments = "fsi " + reportScript)
genPsi.WorkingDirectory <- scriptDir
genPsi.RedirectStandardOutput <- true
genPsi.RedirectStandardError <- true
genPsi.UseShellExecute <- false
genPsi.CreateNoWindow <- true
// Point at fixtures, not real repos
genPsi.EnvironmentVariables.["REPO_SCAN_DIR"] <- fixturesDir
genPsi.EnvironmentVariables.["REPORT_OUTPUT_PATH"] <- reportOutputPath
genPsi.EnvironmentVariables.["MAX_REPOS"] <- "20"
genPsi.EnvironmentVariables.["GITHUB_OWNERS"] <- "test-fixture-no-such-owner-xxx"
let genProc = Process.Start(genPsi)
let genStdout = genProc.StandardOutput.ReadToEnd()
let genStderr = genProc.StandardError.ReadToEnd()
genProc.WaitForExit(120000) |> ignore

printfn "    Exit code: %d" genProc.ExitCode
if genStdout.Length > 0 then
    printfn "    STDOUT:\n%s" genStdout
if genStderr.Length > 0 then
    printfn "    STDERR (verbose):\n%s" genStderr

if genProc.ExitCode <> 0 then
    printfn "    FATAL: Report generation failed with exit code %d" genProc.ExitCode
    failed <- failed + 1
else
    passed <- passed + 1
    printfn "    Report generation succeeded"

// ============================================================
printfn "\n=== TEST: HTML report file exists ==="
assert_true "repo-report.html exists" (File.Exists reportOutputPath)
if not (File.Exists reportOutputPath) then
    printfn "    FATAL: No report at %s — cannot continue" reportOutputPath
    // Cleanup
    try Directory.Delete(fixturesDir, true) with _ -> ()
    printfn "\n\n=========================================="
    printfn "Results: %d passed, %d failed" passed failed
    printfn "=========================================="
    printfn "SOME TESTS FAILED!"
    exit 1

let html = File.ReadAllText(reportOutputPath)

// ============================================================
printfn "\n=== TEST: HTML structure ==="
assert_true "HTML is not empty" (html.Length > 100)
assert_contains "has DOCTYPE" html "<!DOCTYPE html>"
assert_contains "has table" html "<table>"
assert_contains "has h1 title" html "<h1>Repo Report</h1>"
assert_contains "has meta generation line" html "Generated:"
assert_contains "has Repos scanned count" html "Repos scanned:"

// ============================================================
printfn "\n=== TEST: expected columns ==="
assert_contains "has Repository column" html "Repository"
assert_contains "has Uncommitted column" html "Uncommitted"
assert_contains "has Last Commit column" html "Last Commit"
assert_contains "has Branch column" html "Branch"
assert_contains "has PR Branch column" html "PR Branch"
assert_contains "has Push Status column" html "Push Status"
assert_contains "has Open PR column" html "Open PR"
assert_contains "has CI column" html ">CI<"
assert_contains "has CI Date column" html "CI Date"
assert_contains "has CI Error column" html "CI Error"
assert_contains "has Release column" html "Release"

// ============================================================
printfn "\n=== TEST: mock repos appear in report ==="
assert_contains "alpha-service in report" html "alpha-service"
assert_contains "beta-api in report" html "beta-api"
assert_contains "gamma-client in report" html "gamma-client"
assert_contains "delta-lib in report" html "delta-lib"
assert_contains "epsilon-tool in report" html "epsilon-tool"

// ============================================================
printfn "\n=== TEST: branches shown correctly ==="
assert_contains "main branch shown" html "main"
assert_contains "feature/auth branch shown" html "feature/auth"
assert_contains "fix/bug-42 branch shown" html "fix/bug-42"

// ============================================================
printfn "\n=== TEST: uncommitted counts ==="
// beta-api has 3 dirty files, epsilon-tool has 5
// These should show as red (err class) since they're > 0
assert_contains "has err class for dirty repos" html "class=\"err\""
// alpha-service and delta-lib are clean (0) — should show ok class
assert_contains "has ok class for clean repos" html "class=\"ok\""

// ============================================================
printfn "\n=== TEST: tabs ==="
assert_contains "has Repo Status tab" html "Repo Status"
assert_contains "has Community PRs tab" html "Community PRs"
assert_contains "has Community Issues tab" html "Community Issues"
assert_contains "has tab-repos div" html "id=\"tab-repos\""
assert_contains "has tab-prs div" html "id=\"tab-prs\""
assert_contains "has tab-issues div" html "id=\"tab-issues\""

// ============================================================
printfn "\n=== TEST: JavaScript functionality ==="
assert_contains "has showTab function" html "showTab"
assert_contains "has setInterval for auto-refresh" html "setInterval"
assert_contains "has modal-overlay CSS" html "modal-overlay"
assert_contains "has copyLog function" html "copyLog"
assert_contains "has Escape key handler" html "Escape"
assert_true "no meta http-equiv refresh" (not (html.Contains("http-equiv=\"refresh\"")))
assert_contains "JS auto refresh checks for open modal" html "modal-overlay.active"

// ============================================================
printfn "\n=== TEST: community sections handle empty state ==="
// We passed empty GITHUB_OWNERS so no community items
assert_contains "no community PRs message" html "No community PRs found"
assert_contains "no community issues message" html "No community issues found"

// ============================================================
// CLEANUP
// ============================================================
printfn "\n=== CLEANUP ==="
try
    Directory.Delete(fixturesDir, true)
    printfn "    Deleted fixtures dir"
with ex ->
    printfn "    Warning: could not delete fixtures: %s" ex.Message

// ============================================================
printfn "\n\n=========================================="
printfn "Results: %d passed, %d failed" passed failed
printfn "=========================================="
if failed > 0 then
    printfn "SOME TESTS FAILED!"
    exit 1
else
    printfn "ALL TESTS PASSED!"
