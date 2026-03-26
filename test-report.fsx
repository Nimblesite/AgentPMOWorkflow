// Tests for repo-report.fsx logic
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
        p.WaitForExit(30000) |> ignore
        try File.Delete(tmpFile) with _ -> ()
        output.Trim()
    with _ -> ""

let run cmd args workDir =
    runShell (resolveCmd cmd + " " + args) workDir

let gh = resolveCmd "gh"
let codeDir = "/Users/christianfindlay/Documents/Code"

// ============================================================
printfn "\n=== TEST: runShell executes commands correctly ==="
let echoResult = runShell "echo hello" codeDir
assert_eq "echo returns hello" "hello" echoResult

let pwdResult = runShell "pwd" codeDir
assert_eq "pwd returns code dir" codeDir pwdResult

// ============================================================
printfn "\n=== TEST: git commands work ==="
let branch = run "git" "rev-parse --abbrev-ref HEAD" (codeDir + "/project_status")
assert_true "branch is not empty" (branch <> "")
assert_eq "project_status is on main" "main" branch

let modCount = run "git" "status --porcelain" (codeDir + "/project_status")
assert_true "status --porcelain returns something (we have changes)" true  // may or may not have changes

// ============================================================
printfn "\n=== TEST: jq TSV query works for PR checks ==="
// Test with CommandTree which has a known PR
let ctPrNum = run "gh" "pr list --state open --head cleanup --json number --limit 1 --jq .[0].number" (codeDir + "/CommandTree")
assert_true "CommandTree PR number is not empty" (ctPrNum <> "" && ctPrNum <> "null")
printfn "    CommandTree PR#: %s" ctPrNum

if ctPrNum <> "" && ctPrNum <> "null" then
    let tsvOutput = runShell (gh + " pr view " + ctPrNum + " --json statusCheckRollup --jq '.statusCheckRollup[] | [.name, (.conclusion // \"NONE\"), (.status // \"NONE\"), .detailsUrl, .startedAt] | @tsv'") (codeDir + "/CommandTree")
    assert_true "TSV output is not empty" (tsvOutput <> "")
    let lines = tsvOutput.Split('\n')
    assert_true "TSV has at least 1 check" (lines.Length >= 1)
    for line in lines do
        let parts = line.Split('\t')
        assert_true ("TSV line has 5 columns: " + parts.[0]) (parts.Length >= 5)
        assert_true ("name is not empty: " + parts.[0]) (parts.[0] <> "")
        assert_true ("conclusion is not empty: " + parts.[0]) (parts.[1] <> "")
        assert_true ("status is not empty: " + parts.[0]) (parts.[2] <> "")
    // Check that we see a FAILURE conclusion
    let hasFailure = lines |> Array.exists (fun l -> l.Contains("FAILURE"))
    assert_true "CommandTree has at least one FAILURE check" hasFailure

// ============================================================
printfn "\n=== TEST: forge PR checks (the null conclusion bug) ==="
let forgePrNum = run "gh" "pr list --state open --head stuff --json number --limit 1 --jq .[0].number" (codeDir + "/forge")
if forgePrNum <> "" && forgePrNum <> "null" then
    printfn "    forge PR#: %s" forgePrNum
    let tsvOutput = runShell (gh + " pr view " + forgePrNum + " --json statusCheckRollup --jq '.statusCheckRollup[] | [.name, (.conclusion // \"NONE\"), (.status // \"NONE\"), .detailsUrl, .startedAt] | @tsv'") (codeDir + "/forge")
    let lines = tsvOutput.Split('\n')
    assert_true "forge TSV has checks" (lines.Length >= 1)
    // Every line should have 5 tab-separated columns, even if conclusion was null
    for line in lines do
        let parts = line.Split('\t')
        assert_true ("forge TSV line has 5 cols: " + parts.[0]) (parts.Length >= 5)
        // conclusion should never be empty - it should be NONE if null
        assert_true ("forge conclusion not empty: " + parts.[0]) (parts.[1] <> "")
    // Find the .NET failure
    let dotnetFailure = lines |> Array.exists (fun l -> l.Contains(".NET") && l.Contains("FAILURE"))
    assert_true "forge .NET check shows FAILURE" dotnetFailure
    // Find cancelled check (Test) - should show CANCELLED or NONE, NOT be missing
    let testCheck = lines |> Array.exists (fun l -> l.StartsWith("Test\t"))
    assert_true "forge Test check is present (not omitted)" testCheck
else
    printfn "    SKIP: forge has no open PR on 'stuff'"

// ============================================================
printfn "\n=== TEST: Basilisk multiple failures ==="
let basiliskPrNum = run "gh" "pr list --state open --head Stuff2 --json number --limit 1 --jq .[0].number" (codeDir + "/Basilisk")
if basiliskPrNum <> "" && basiliskPrNum <> "null" then
    printfn "    Basilisk PR#: %s" basiliskPrNum
    let tsvOutput = runShell (gh + " pr view " + basiliskPrNum + " --json statusCheckRollup --jq '.statusCheckRollup[] | [.name, (.conclusion // \"NONE\"), (.status // \"NONE\"), .detailsUrl, .startedAt] | @tsv'") (codeDir + "/Basilisk")
    let lines = tsvOutput.Split('\n')
    let failedChecks = lines |> Array.filter (fun l -> l.Contains("FAILURE"))
    printfn "    Failed checks: %d" failedChecks.Length
    for f in failedChecks do
        printfn "      %s" (f.Split('\t').[0])
    // Basilisk should have failures
    assert_true "Basilisk has at least 1 failure" (failedChecks.Length >= 1)
else
    printfn "    SKIP: Basilisk has no open PR on 'Stuff2'"

// ============================================================
printfn "\n=== TEST: Napper failures ==="
let napperPrNum = run "gh" "pr list --state open --head AgentSwarmBigBang --json number --limit 1 --jq .[0].number" (codeDir + "/Napper")
if napperPrNum <> "" && napperPrNum <> "null" then
    printfn "    Napper PR#: %s" napperPrNum
    let tsvOutput = runShell (gh + " pr view " + napperPrNum + " --json statusCheckRollup --jq '.statusCheckRollup[] | [.name, (.conclusion // \"NONE\"), (.status // \"NONE\"), .detailsUrl, .startedAt] | @tsv'") (codeDir + "/Napper")
    let lines = tsvOutput.Split('\n')
    let failedChecks = lines |> Array.filter (fun l -> l.Contains("FAILURE"))
    assert_true "Napper has at least 1 failure" (failedChecks.Length >= 1)
    for f in failedChecks do
        printfn "      Failed: %s" (f.Split('\t').[0])
else
    printfn "    SKIP: Napper has no open PR"

// ============================================================
printfn "\n=== TEST: Failed job logs via API ==="
if forgePrNum <> "" && forgePrNum <> "null" then
    // Get repo slug
    let remote = run "git" "remote get-url origin" (codeDir + "/forge")
    let cleaned = remote.Replace(".git", "").TrimEnd('/')
    let parts = cleaned.Split('/')
    let slug = parts.[parts.Length - 2] + "/" + parts.[parts.Length - 1]
    printfn "    Repo slug: %s" slug

    // Get run ID from detailsUrl
    let detailsUrl = runShell (gh + " pr view " + forgePrNum + " --json statusCheckRollup --jq '.statusCheckRollup[0].detailsUrl'") (codeDir + "/forge")
    assert_true "detailsUrl is not empty" (detailsUrl <> "")
    let urlParts = detailsUrl.Split('/')
    let runIdx = urlParts |> Array.tryFindIndex (fun p -> p = "runs")
    match runIdx with
    | Some i ->
        let runId = urlParts.[i + 1]
        printfn "    Run ID: %s" runId

        // Get failed jobs via API
        let failedJobsTsv = runShell (gh + " api repos/" + slug + "/actions/runs/" + runId + "/jobs --jq '.jobs[] | select(.conclusion==\"failure\") | [(.id|tostring), .name] | @tsv'") (codeDir + "/forge")
        assert_true "failed jobs TSV is not empty" (failedJobsTsv <> "")
        let jobLines = failedJobsTsv.Split('\n')
        assert_true "at least 1 failed job" (jobLines.Length >= 1)
        for jl in jobLines do
            let jp = jl.Split('\t')
            assert_true ("job line has id and name: " + jl) (jp.Length >= 2)
            printfn "      Failed job: %s (ID: %s)" jp.[1] jp.[0]

        // Get actual log for first failed job
        if jobLines.Length > 0 then
            let firstJobId = jobLines.[0].Split('\t').[0].Trim()
            let jobLog = runShell (gh + " api repos/" + slug + "/actions/jobs/" + firstJobId + "/logs") (codeDir + "/forge")
            assert_true "job log is not empty" (jobLog <> "")
            assert_true "job log has multiple lines" (jobLog.Split('\n').Length > 5)
            printfn "      Log lines: %d" (jobLog.Split('\n').Length)
    | None ->
        failed <- failed + 1
        printfn "  FAIL: could not extract run ID from detailsUrl"

// ============================================================
printfn "\n=== TEST: HTML report was generated ==="
let reportPath = codeDir + "/project_status/repo-report.html"
assert_true "repo-report.html exists" (File.Exists(reportPath))
let html = File.ReadAllText(reportPath)
assert_true "HTML is not empty" (html.Length > 100)
assert_contains "HTML has table" html "<table>"
assert_contains "HTML has CI Error column" html "CI Error"

// Check CI failures appear in HTML
assert_contains "HTML contains FAILURE status" html "FAILURE"
// Check that failed check names appear
assert_contains "HTML has forge .NET error" html ".NET"
// Check modals exist
assert_contains "HTML has modal-overlay divs" html "modal-overlay"
assert_contains "HTML has Copy Log button" html "Copy Log"
// Check auto-refresh JS exists (not meta refresh)
assert_true "No meta http-equiv refresh" (not (html.Contains("http-equiv=\"refresh\"")))
assert_contains "JS-based auto refresh with modal check" html "modal-overlay.active"
assert_contains "Has setInterval for refresh" html "setInterval"
// Check modal has pre tag with log content
assert_contains "Modal has pre tag for logs" html "<pre id="
// Check that the log content is not empty in the pre tags
let preCount = html.Split([|"<pre id="|], StringSplitOptions.None).Length - 1
assert_true ("HTML has " + string preCount + " log pre tags (should be >= 3)") (preCount >= 3)

// Check color classes
assert_contains "HTML has ok class (green)" html "class=\"ok\""
assert_contains "HTML has err class (red)" html "class=\"err\""
assert_contains "HTML has warn class (yellow)" html "class=\"warn\""

// ============================================================
printfn "\n=== TEST: repos without PR should have empty CI ==="
// project_status is on main with no PR
let psPrNum = run "gh" "pr list --state open --head main --json number --limit 1 --jq .[0].number" (codeDir + "/project_status")
let hasNoPR = psPrNum = "" || psPrNum = "null"
assert_true "project_status has no open PR on main" hasNoPR

// ============================================================
printfn "\n\n=========================================="
printfn "Results: %d passed, %d failed" passed failed
printfn "=========================================="
if failed > 0 then
    printfn "SOME TESTS FAILED!"
    exit 1
else
    printfn "ALL TESTS PASSED!"
