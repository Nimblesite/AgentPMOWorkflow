open System
open System.IO
open System.Diagnostics
open System.Text

let resolveCmd (cmd: string) =
    let paths = [| "/opt/homebrew/bin"; "/usr/local/bin"; "/usr/bin"; "/bin" |]
    match paths |> Array.tryFind (fun p -> File.Exists(Path.Combine(p, cmd))) with
    | Some p -> Path.Combine(p, cmd)
    | None -> cmd

let runShell (cmdLine: string) workDir =
    eprintfn "[CMD] %s (in %s)" cmdLine workDir
    try
        // Write command to temp file to avoid shell escaping issues
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
        let result = output.Trim()
        try File.Delete(tmpFile) with _ -> ()
        eprintfn "[OUT] %s" (if result.Length > 300 then result.[0..299] + "..." else result)
        if not (String.IsNullOrWhiteSpace(stderr)) then
            eprintfn "[ERR] %s" (stderr.Trim())
        result
    with ex ->
        eprintfn "[EXCEPTION] %s" (ex.Message)
        ""

let run cmd args workDir =
    let resolved = resolveCmd cmd
    runShell (resolved + " " + args) workDir

let isGitRepo dir =
    Directory.Exists(Path.Combine(dir, ".git"))

let getModifiedCount dir =
    let output = run "git" "status --porcelain" dir
    if String.IsNullOrWhiteSpace(output) then 0
    else output.Split('\n') |> Array.filter (fun l -> l.Trim() <> "") |> Array.length

let getLastEditDate dir =
    // %ci gives local time like "2026-03-26 14:30:00 +1100"
    let output = run "git" "log -1 --format=%ci HEAD" dir
    if String.IsNullOrWhiteSpace(output) then "unknown"
    else
        let parts = output.Split(' ')
        if parts.Length >= 2 then parts.[0] + " " + parts.[1].[0..4] // "2026-03-26 14:30"
        else output

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

let parsePR (tsv: string) =
    if String.IsNullOrWhiteSpace(tsv) then ("", "", "", "")
    else
        let parts = tsv.Split('\t')
        if parts.Length >= 4 then
            let clean (s: string) = if String.IsNullOrWhiteSpace(s) || s = "null" then "" else s.Trim()
            (clean parts.[0], clean parts.[1], clean parts.[2], clean parts.[3])
        else ("", "", "", "")

let getOpenPR (dir: string) currentBranch =
    eprintfn "[PR] Looking for open PR with --head %s in %s" currentBranch (Path.GetFileName(dir))
    let gh = resolveCmd "gh"
    let jqExpr = "'[.[0].title, .[0].headRefName, (.[0].number|tostring), .[0].url] | @tsv'"
    let headTsv = runShell (gh + " pr list --state open --head " + currentBranch + " --json title,headRefName,number,url --limit 1 --jq " + jqExpr) dir
    let t, b, n, u = parsePR headTsv
    if t <> "" then
        eprintfn "[PR] Found PR on current branch: title='%s' branch='%s' number='%s' url='%s'" t b n u
        (t, b, n, u)
    else
        eprintfn "[PR] No PR on current branch, checking all open PRs"
        let anyTsv = runShell (gh + " pr list --state open --json title,headRefName,number,url --limit 1 --jq " + jqExpr) dir
        let t2, b2, n2, u2 = parsePR anyTsv
        eprintfn "[PR] Fallback result: title='%s' branch='%s' number='%s' url='%s'" t2 b2 n2 u2
        (t2, b2, n2, u2)

let getRepoSlug (dir: string) =
    let remote = run "git" "remote get-url origin" dir
    if String.IsNullOrWhiteSpace(remote) then ""
    else
        // Handle both HTTPS and SSH URLs
        let cleaned = remote.Replace(".git", "").TrimEnd('/')
        if cleaned.Contains("github.com") then
            let parts = cleaned.Split('/')
            if parts.Length >= 2 then parts.[parts.Length - 2] + "/" + parts.[parts.Length - 1]
            else ""
        else ""

let getCIStatus (dir: string) (prNumber: string) =
    if prNumber = "" then
        eprintfn "[CI] Skipping CI for %s (no PR)" (Path.GetFileName(dir))
        ("", "", "", "", "")
    else
        eprintfn "[CI] Checking PR #%s for %s" prNumber (Path.GetFileName(dir))
        let gh = resolveCmd "gh"
        // Get all checks as TSV: name\tconclusion\tstatus\tdetailsUrl\tstartedAt
        let tsvOutput = runShell (gh + " pr view " + prNumber + " --json statusCheckRollup --jq '.statusCheckRollup[] | [.name, (.conclusion // \"NONE\"), (.status // \"NONE\"), .detailsUrl, .startedAt] | @tsv'") dir
        let checks =
            if String.IsNullOrWhiteSpace(tsvOutput) then [||]
            else
                tsvOutput.Split('\n')
                |> Array.choose (fun line ->
                    let parts = line.Split('\t')
                    if parts.Length >= 5 then
                        Some {| Name = parts.[0]; Conclusion = parts.[1].ToUpperInvariant(); Status = parts.[2].ToUpperInvariant(); DetailsUrl = parts.[3]; StartedAt = parts.[4] |}
                    else None)
        eprintfn "[CI] Found %d checks" checks.Length
        for c in checks do
            eprintfn "[CI]   %s: conclusion=%s status=%s" c.Name c.Conclusion c.Status

        let hasFailure = checks |> Array.exists (fun c -> c.Conclusion = "FAILURE" || c.Conclusion = "ERROR" || c.Conclusion = "STARTUP_FAILURE")
        let hasCancelled = checks |> Array.exists (fun c -> c.Conclusion = "CANCELLED")
        let hasInProgress = checks |> Array.exists (fun c -> c.Status = "IN_PROGRESS" || c.Status = "PENDING" || c.Status = "QUEUED")
        let hasSuccess = checks |> Array.exists (fun c -> c.Conclusion = "SUCCESS")
        let aggregate =
            if hasFailure then "FAILURE"
            elif hasCancelled then "CANCELLED"
            elif hasInProgress then "IN_PROGRESS"
            elif hasSuccess then "SUCCESS"
            elif checks.Length > 0 then checks.[0].Conclusion
            else ""

        let firstStarted = if checks.Length > 0 then checks.[0].StartedAt else ""
        // Convert UTC ISO date to local time
        let dateShort =
            if String.IsNullOrWhiteSpace(firstStarted) then ""
            else
                match DateTime.TryParse(firstStarted, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.RoundtripKind) with
                | true, dt -> dt.ToLocalTime().ToString("yyyy-MM-dd HH:mm")
                | _ -> if firstStarted.Length >= 16 then firstStarted.[0..15].Replace("T", " ") else firstStarted

        let failedCheckNames =
            checks
            |> Array.filter (fun c -> c.Conclusion = "FAILURE" || c.Conclusion = "ERROR" || c.Conclusion = "STARTUP_FAILURE")
            |> Array.map (fun c -> c.Name)
            |> fun arr -> String.Join(" | ", arr)

        // Get failed job logs via API (works even when run is still in progress)
        let repoSlug = getRepoSlug dir
        let failedLog =
            if repoSlug = "" || not hasFailure then ""
            else
                let runIds =
                    checks
                    |> Array.choose (fun c ->
                        let parts = c.DetailsUrl.Split('/')
                        let idx = parts |> Array.tryFindIndex (fun p -> p = "runs")
                        match idx with
                        | Some i when i + 1 < parts.Length -> Some parts.[i + 1]
                        | _ -> None)
                    |> Array.distinct
                eprintfn "[CI] Run IDs: %s" (String.Join(", ", runIds))
                let logs = System.Collections.Generic.List<string>()
                for runId in runIds do
                    // Get failed job IDs and names via API as TSV
                    let jobsTsv = runShell (gh + " api repos/" + repoSlug + "/actions/runs/" + runId + "/jobs --jq '.jobs[] | select(.conclusion==\"failure\") | [(.id|tostring), .name] | @tsv'") dir
                    if not (String.IsNullOrWhiteSpace(jobsTsv)) then
                        for jobLine in jobsTsv.Split('\n') do
                            let parts = jobLine.Split('\t')
                            if parts.Length >= 2 then
                                let jobId = parts.[0].Trim()
                                let jobName = parts.[1].Trim()
                                eprintfn "[CI] Fetching log for failed job %s (%s)" jobId jobName
                                let jobLog = runShell (gh + " api repos/" + repoSlug + "/actions/jobs/" + jobId + "/logs") dir
                                if not (String.IsNullOrWhiteSpace(jobLog)) then
                                    logs.Add("=== " + jobName + " ===\n" + jobLog)
                String.Join("\n\n", logs)

        let ciUrl =
            checks
            |> Array.tryPick (fun c ->
                if not (String.IsNullOrWhiteSpace(c.DetailsUrl)) then Some c.DetailsUrl
                else None)
            |> Option.defaultValue ""

        let errorText = if String.IsNullOrWhiteSpace(failedCheckNames) then "" else failedCheckNames
        let fullLog = if String.IsNullOrWhiteSpace(failedLog) then "" else failedLog.Trim()
        eprintfn "[CI] Result: aggregate='%s' date='%s' errors='%s' url='%s' logLines=%d" aggregate dateShort errorText ciUrl (if fullLog = "" then 0 else fullLog.Split('\n').Length)
        (aggregate, dateShort, errorText, fullLog, ciUrl)

let getLatestRelease (dir: string) =
    eprintfn "[REL] Checking latest release for %s" (Path.GetFileName(dir))
    let gh = resolveCmd "gh"
    let tsv = runShell (gh + " release view --json tagName,publishedAt --jq '[.tagName, .publishedAt] | @tsv'") dir
    if String.IsNullOrWhiteSpace(tsv) then ("", "", "")
    else
        let parts = tsv.Split('\t')
        if parts.Length >= 2 then
            let tag = parts.[0].Trim()
            let raw = parts.[1].Trim()
            let dateShort =
                match DateTime.TryParse(raw, System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.RoundtripKind) with
                | true, dt -> dt.ToLocalTime().ToString("yyyy-MM-dd")
                | _ -> if raw.Length >= 10 then raw.[0..9] else raw
            let slug = getRepoSlug dir
            let url =
                if slug <> "" then "https://github.com/" + slug + "/releases/tag/" + tag
                else ""
            eprintfn "[REL] Result: tag='%s' date='%s' url='%s'" tag dateShort url
            (tag, dateShort, url)
        else ("", "", "")

let escape (s: string) =
    s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")

// ── Configuration ─────────────────────────────────────────────────────────────
// Priority: environment variable > config.json > built-in default.
// See config.example.json for the schema.

let private envStr (key: string) =
    let v = Environment.GetEnvironmentVariable(key)
    if String.IsNullOrWhiteSpace(v) then "" else v.Trim()

let private scriptDir =
    let s = __SOURCE_DIRECTORY__
    if String.IsNullOrWhiteSpace(s) then Directory.GetCurrentDirectory() else s

let private configPath = Path.Combine(scriptDir, "config.json")

// Minimal JSON value parser — handles only the flat object we need.
// Avoids a NuGet dependency for a five-field config file.
let private configValues =
    if File.Exists(configPath) then
        eprintfn "[CONFIG] Loading %s" configPath
        let lines = File.ReadAllText(configPath)
        lines.Split('\n')
        |> Array.choose (fun line ->
            let t = line.Trim().TrimEnd(',')
            if t.StartsWith("\"") then
                let colonIdx = t.IndexOf(':')
                if colonIdx > 0 then
                    let key = t.[1 .. colonIdx - 1].Trim().TrimEnd('"')
                    let raw = t.[colonIdx + 1 ..].Trim()
                    let value =
                        if raw.StartsWith("\"") && raw.EndsWith("\"") then raw.[1 .. raw.Length - 2]
                        else raw
                    Some (key, value)
                else None
            else None)
        |> Map.ofArray
    else
        eprintfn "[CONFIG] No config.json found at %s — using defaults + env vars" scriptDir
        Map.empty

let private cfgStr (key: string) =
    match configValues |> Map.tryFind key with
    | Some v when not (String.IsNullOrWhiteSpace(v)) -> v
    | _ -> ""

let private cfgArr (key: string) =
    let v = cfgStr key
    if v = "" then [||]
    else v.Split(',') |> Array.map (fun s -> s.Trim()) |> Array.filter (fun s -> s <> "")

// Resolve each setting: env var wins, then config.json, then default.
let scanDir =
    let fromEnv = envStr "REPO_SCAN_DIR"
    if fromEnv <> "" && Directory.Exists(fromEnv) then fromEnv
    else
        let fromCfg = cfgStr "scanDir"
        if fromCfg <> "" && Directory.Exists(fromCfg) then fromCfg
        else Directory.GetParent(scriptDir).FullName

let reportOutputPath =
    let fromEnv = envStr "REPORT_OUTPUT_PATH"
    if fromEnv <> "" then fromEnv
    else
        let fromCfg = cfgStr "reportOutputPath"
        if fromCfg <> "" then fromCfg
        else Path.Combine(scriptDir, "repo-report.html")

let githubOwners =
    let fromEnv = envStr "GITHUB_OWNERS"
    if fromEnv <> "" then fromEnv.Split(',') |> Array.map (fun s -> s.Trim()) |> Array.filter (fun s -> s <> "")
    else cfgArr "githubOwners"

let excludeAuthor =
    let fromEnv = envStr "GITHUB_EXCLUDE_AUTHOR"
    (if fromEnv <> "" then fromEnv else cfgStr "excludeAuthor").ToLowerInvariant()

let excludeRepoDomain =
    let fromEnv = envStr "GITHUB_EXCLUDE_REPO_DOMAIN"
    (if fromEnv <> "" then fromEnv else cfgStr "excludeRepoDomain").ToLowerInvariant()

let maxRepos =
    let fromEnv = envStr "MAX_REPOS"
    let fromCfg = cfgStr "maxRepos"
    let raw = if fromEnv <> "" then fromEnv elif fromCfg <> "" then fromCfg else "20"
    match System.Int32.TryParse(raw) with
    | true, n when n > 0 -> n
    | _ -> 20

let excludeRepos =
    let fromEnv = envStr "EXCLUDE_REPOS"
    let raw = if fromEnv <> "" then fromEnv else cfgStr "excludeRepos"
    if raw = "" then Set.empty
    else raw.Split(',') |> Array.map (fun s -> s.Trim().ToLowerInvariant()) |> Array.filter (fun s -> s <> "") |> Set.ofArray

eprintfn "[CONFIG] scanDir=%s  reportOutputPath=%s  githubOwners=%s  maxRepos=%d  excludeRepos=%s" scanDir reportOutputPath (String.Join(",", githubOwners)) maxRepos (String.Join(",", excludeRepos))
// ──────────────────────────────────────────────────────────────────────────────

type CommunityItem = {
    Number: string
    Title: string
    Author: string
    Repo: string
    Url: string
    CreatedAt: string
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

let searchCommunityItems (itemType: string) (owner: string) : CommunityItem[] =
    eprintfn "[COMMUNITY] Searching %s for owner=%s" itemType owner
    let gh = resolveCmd "gh"
    let jq = "'.[] | [(.number|tostring), .title, .author.login, .repository.nameWithOwner, .url, .createdAt] | @tsv'"
    let tsvOutput = runShell (gh + " search " + itemType + " --owner " + owner + " --state open --json number,title,author,repository,url,createdAt --limit 50 --jq " + jq) "/"
    if String.IsNullOrWhiteSpace(tsvOutput) then [||]
    else
        tsvOutput.Split('\n')
        |> Array.choose parseCommunityItem
        |> Array.filter (fun item ->
            let author = item.Author.ToLowerInvariant()
            let repo = item.Repo.ToLowerInvariant()
            (excludeAuthor = "" || author <> excludeAuthor)
            && not (author.Contains("dependabot"))
            && not (author.Contains("[bot]"))
            && (excludeRepoDomain = "" || not (repo.Contains(excludeRepoDomain))))

let getCommunityItems (itemType: string) : CommunityItem[] =
    githubOwners
    |> Array.collect (searchCommunityItems itemType)
    |> Array.sortByDescending (fun item -> item.CreatedAt)

printfn "Scanning repos in %s..." scanDir

let allDirs =
    Directory.GetDirectories(scanDir)
    |> Array.filter isGitRepo
    |> Array.filter (fun dir -> not (excludeRepos.Contains(Path.GetFileName(dir).ToLowerInvariant())))

printfn "Found %d git repos (after exclusions)" allDirs.Length

// First pass: sort by folder modified date (cheap, no git calls)
let candidateDirs =
    allDirs
    |> Array.sortByDescending (fun dir -> Directory.GetLastWriteTimeUtc(dir))

// Second pass: get last commit date for each candidate, pick top N
printfn "Getting commit dates for %d repos..." candidateDirs.Length
let dirs =
    candidateDirs
    |> Array.map (fun dir ->
        let commitDate = getLastEditDate dir
        eprintfn "[SORT] %s  commit=%s" (Path.GetFileName(dir)) commitDate
        (dir, commitDate))
    |> Array.sortByDescending snd
    |> Array.truncate maxRepos
    |> Array.map fst

printfn "Selected top %d repos by last commit date" dirs.Length

type RepoInfo = {
    Name: string
    FolderModified: DateTime
    ModifiedCount: int
    LastEdit: string
    Branch: string
    PRBranch: string
    PushStatus: string
    OpenPR: string
    PRUrl: string
    CIStatus: string
    CIDate: string
    CIError: string
    CILog: string
    CIUrl: string
    ReleaseTag: string
    ReleaseDate: string
    ReleaseUrl: string
}

let repos =
    dirs
    |> Array.map (fun dir ->
        let name = Path.GetFileName(dir)
        let folderMod = Directory.GetLastWriteTimeUtc(dir)
        eprintfn "\n=== %s === (modified: %s)" name (folderMod.ToString("yyyy-MM-dd HH:mm:ss"))
        printfn "  %s..." name
        let modCount = getModifiedCount dir
        let lastEdit = getLastEditDate dir
        let branch = getBranch dir
        let pushStatus = getPushStatus dir
        let openPR, prBranch, prNumber, prUrl = getOpenPR dir branch
        let ciStatus, ciDate, ciError, ciLog, ciUrl = getCIStatus dir prNumber
        let relTag, relDate, relUrl = getLatestRelease dir
        { Name = name; FolderModified = folderMod; ModifiedCount = modCount; LastEdit = lastEdit
          Branch = branch; PRBranch = prBranch; PushStatus = pushStatus; OpenPR = openPR
          PRUrl = prUrl; CIStatus = ciStatus; CIDate = ciDate; CIError = ciError
          CILog = ciLog; CIUrl = ciUrl
          ReleaseTag = relTag; ReleaseDate = relDate; ReleaseUrl = relUrl }
    )
    |> Array.sortByDescending (fun r -> r.LastEdit)

printfn "\nBuilding report for %d repos..." repos.Length

printfn "Fetching community PRs..."
let communityPRs = getCommunityItems "prs"
printfn "Found %d community PRs" communityPRs.Length

printfn "Fetching community issues..."
let communityIssues = getCommunityItems "issues"
printfn "Found %d community issues" communityIssues.Length

let sb = StringBuilder()

let a (s: string) = sb.AppendLine(s) |> ignore

a "<!DOCTYPE html>"
a "<html lang=\"en\">"
a "<head>"
a "<meta charset=\"UTF-8\">"
// No meta refresh - handled by JS that pauses when modal is open
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
a "td a { color: inherit; text-decoration: none; }"
a "td a:hover { text-decoration: underline; }"
a ".ci-err { max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: #e53e3e; font-size: 0.8rem; cursor: pointer; }"
a ".ci-err:hover { text-decoration: underline; }"
a ".modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1000; justify-content: center; align-items: center; }"
a ".modal-overlay.active { display: flex; }"
a ".modal { background: white; border-radius: 12px; padding: 0; width: 80%; max-width: 900px; max-height: 80vh; display: flex; flex-direction: column; box-shadow: 0 8px 32px rgba(0,0,0,0.3); }"
a ".modal-header { display: flex; justify-content: space-between; align-items: center; padding: 16px 20px; border-bottom: 1px solid #e2e8f0; }"
a ".modal-header h3 { margin: 0; font-size: 0.95rem; color: #2d3748; }"
a ".modal-actions { display: flex; gap: 8px; }"
a ".modal-btn { padding: 6px 14px; border: 1px solid #cbd5e0; border-radius: 6px; background: white; cursor: pointer; font-size: 0.8rem; color: #4a5568; }"
a ".modal-btn:hover { background: #f7fafc; }"
a ".modal-btn.close { border: none; font-size: 1.2rem; padding: 4px 8px; color: #a0aec0; }"
a ".modal-btn.close:hover { color: #2d3748; }"
a ".modal-body { overflow-y: auto; padding: 16px 20px; flex: 1; }"
a ".modal-body pre { margin: 0; font-size: 0.75rem; line-height: 1.5; white-space: pre-wrap; word-break: break-all; font-family: 'SF Mono', Monaco, monospace; color: #2d3748; background: #f7fafc; padding: 12px; border-radius: 6px; }"
a ".tabs { display: flex; gap: 0; margin-bottom: 16px; border-bottom: 2px solid #e2e8f0; }"
a ".tab-btn { padding: 10px 24px; border: none; background: none; cursor: pointer; font-size: 0.9rem; color: #718096; border-bottom: 3px solid transparent; margin-bottom: -2px; transition: color 0.15s; }"
a ".tab-btn:hover { color: #2d3748; }"
a ".tab-btn.active { color: #2b6cb0; font-weight: 600; border-bottom: 3px solid #2b6cb0; }"
a ".tab-content { display: none; }"
a ".tab-content.active { display: block; }"
a ".community-table td a { color: #2b6cb0; }"
a ".filter-bar { margin-bottom: 12px; display: flex; align-items: center; gap: 8px; font-size: 0.85rem; color: #4a5568; }"
a ".filter-bar input[type=checkbox] { width: 16px; height: 16px; cursor: pointer; }"
a ".filter-bar label { cursor: pointer; user-select: none; }"
a "</style>"
a "</head>"
a "<body>"
a "<h1>Repo Report</h1>"

let metaLine = "<p class=\"meta\">Generated: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + " &nbsp;|&nbsp; Repos scanned: " + string repos.Length + "</p>"
a metaLine

a "<div class=\"tabs\">"
a "<button class=\"tab-btn active\" data-tab=\"tab-repos\" onclick=\"showTab('tab-repos')\">Repo Status</button>"
a ("<button class=\"tab-btn\" data-tab=\"tab-prs\" onclick=\"showTab('tab-prs')\">Community PRs (" + string communityPRs.Length + ")</button>")
a ("<button class=\"tab-btn\" data-tab=\"tab-issues\" onclick=\"showTab('tab-issues')\">Community Issues (" + string communityIssues.Length + ")</button>")
a "</div>"

a "<div class=\"tab-content active\" id=\"tab-repos\">"

if repos.Length = 0 then
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
    a "<th>Release</th>"
    a "</tr></thead>"
    a "<tbody>"

    for r in repos do
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
        if r.PRUrl <> "" && r.OpenPR <> "" then
            a ("<td><a href=\"" + escape r.PRUrl + "\" target=\"_blank\">" + escape r.OpenPR + "</a></td>")
        else
            a ("<td>" + escape r.OpenPR + "</td>")
        if r.CIUrl <> "" && r.CIStatus <> "" then
            a ("<td class=\"" + ciClass + "\"><a href=\"" + escape r.CIUrl + "\" target=\"_blank\">" + escape r.CIStatus + "</a></td>")
        else
            a ("<td class=\"" + ciClass + "\">" + escape r.CIStatus + "</td>")
        a ("<td>" + escape r.CIDate + "</td>")
        let errDisplay = r.CIError.Replace("\n", " | ")
        if errDisplay <> "" then
            let modalId = "modal-" + r.Name.Replace(" ", "-").Replace(".", "-")
            a ("<td class=\"ci-err\" onclick=\"document.getElementById('" + modalId + "').classList.add('active')\">" + escape errDisplay + "</td>")
        else
            a "<td></td>"
        if r.ReleaseTag <> "" then
            let relText = r.ReleaseTag + " (" + r.ReleaseDate + ")"
            if r.ReleaseUrl <> "" then
                a ("<td><a href=\"" + escape r.ReleaseUrl + "\" target=\"_blank\">" + escape relText + "</a></td>")
            else
                a ("<td>" + escape relText + "</td>")
        else
            a "<td></td>"
        a "</tr>"

    a "</tbody>"
    a "</table>"

    // Render modals for repos with CI errors
    for r in repos do
        if r.CIError <> "" then
            let modalId = "modal-" + r.Name.Replace(" ", "-").Replace(".", "-")
            let logId = "log-" + r.Name.Replace(" ", "-").Replace(".", "-")
            // Strip ANSI escape codes from the log
            let cleanLog = System.Text.RegularExpressions.Regex.Replace(r.CILog, @"\x1B\[[0-9;]*m", "")
            a ("<div class=\"modal-overlay\" id=\"" + modalId + "\" onclick=\"if(event.target===this)this.classList.remove('active')\">")
            a "<div class=\"modal\">"
            a "<div class=\"modal-header\">"
            a ("<h3>CI Failure: " + escape r.Name + " — " + escape r.CIError + "</h3>")
            a "<div class=\"modal-actions\">"
            a ("<button class=\"modal-btn\" onclick=\"copyLog('" + logId + "')\">Copy Log</button>")
            a ("<button class=\"modal-btn close\" onclick=\"document.getElementById('" + modalId + "').classList.remove('active')\">&times;</button>")
            a "</div>"
            a "</div>"
            a "<div class=\"modal-body\">"
            a ("<pre id=\"" + logId + "\">" + escape cleanLog + "</pre>")
            a "</div>"
            a "</div>"
            a "</div>"

a "</div>" // end tab-repos

// Owners list embedded in HTML for JS filtering
let ownersJson = "[" + (githubOwners |> Array.map (fun o -> "\"" + escape (o.ToLowerInvariant()) + "\"") |> fun arr -> String.Join(",", arr)) + "]"

// Tab 2: Community PRs
a "<div class=\"tab-content\" id=\"tab-prs\">"
if communityPRs.Length = 0 then
    a "<p>No community PRs found.</p>"
else
    a "<div class=\"filter-bar\">"
    a "<input type=\"checkbox\" id=\"exclude-owner-prs\" onchange=\"applyOwnerFilter('tab-prs', this.checked)\">"
    a "<label for=\"exclude-owner-prs\">Hide owner PRs</label>"
    a "</div>"
    a "<table class=\"community-table\">"
    a "<thead><tr><th>#</th><th>Repository</th><th>Title</th><th>Author</th><th>Created</th></tr></thead>"
    a "<tbody>"
    for item in communityPRs do
        a ("<tr data-author=\"" + escape (item.Author.ToLowerInvariant()) + "\">")
        a ("<td><a href=\"" + escape item.Url + "\" target=\"_blank\">#" + escape item.Number + "</a></td>")
        a ("<td><span class=\"mono\">" + escape item.Repo + "</span></td>")
        a ("<td><a href=\"" + escape item.Url + "\" target=\"_blank\">" + escape item.Title + "</a></td>")
        a ("<td>" + escape item.Author + "</td>")
        a ("<td>" + escape (if item.CreatedAt.Length >= 10 then item.CreatedAt.[0..9] else item.CreatedAt) + "</td>")
        a "</tr>"
    a "</tbody></table>"
a "</div>"

// Tab 3: Community Issues
a "<div class=\"tab-content\" id=\"tab-issues\">"
if communityIssues.Length = 0 then
    a "<p>No community issues found.</p>"
else
    a "<div class=\"filter-bar\">"
    a "<input type=\"checkbox\" id=\"exclude-owner-issues\" onchange=\"applyOwnerFilter('tab-issues', this.checked)\">"
    a "<label for=\"exclude-owner-issues\">Hide owner issues</label>"
    a "</div>"
    a "<table class=\"community-table\">"
    a "<thead><tr><th>#</th><th>Repository</th><th>Title</th><th>Author</th><th>Created</th></tr></thead>"
    a "<tbody>"
    for item in communityIssues do
        a ("<tr data-author=\"" + escape (item.Author.ToLowerInvariant()) + "\">")
        a ("<td><a href=\"" + escape item.Url + "\" target=\"_blank\">#" + escape item.Number + "</a></td>")
        a ("<td><span class=\"mono\">" + escape item.Repo + "</span></td>")
        a ("<td><a href=\"" + escape item.Url + "\" target=\"_blank\">" + escape item.Title + "</a></td>")
        a ("<td>" + escape item.Author + "</td>")
        a ("<td>" + escape (if item.CreatedAt.Length >= 10 then item.CreatedAt.[0..9] else item.CreatedAt) + "</td>")
        a "</tr>"
    a "</tbody></table>"
a "</div>"

a ("<script>var owners = " + ownersJson + ";")
a "function applyOwnerFilter(tabId, hide) {"
a "  localStorage.setItem('hideOwner_' + tabId, hide ? '1' : '0');"
a "  var rows = document.querySelectorAll('#' + tabId + ' tbody tr');"
a "  rows.forEach(function(row) {"
a "    var author = row.getAttribute('data-author');"
a "    row.style.display = (hide && owners.indexOf(author) !== -1) ? 'none' : '';"
a "  });"
a "}"
a "(function() {"
a "  ['tab-prs', 'tab-issues'].forEach(function(tabId) {"
a "    var key = 'hideOwner_' + tabId;"
a "    var stored = localStorage.getItem(key);"
a "    var hide = stored === null ? true : stored === '1';"
a "    var suffix = tabId === 'tab-prs' ? 'prs' : 'issues';"
a "    var cb = document.getElementById('exclude-owner-' + suffix);"
a "    if (cb) { cb.checked = hide; applyOwnerFilter(tabId, hide); }"
a "  });"
a "})();"
a "function copyLog(id) {"
a "  const el = document.getElementById(id);"
a "  navigator.clipboard.writeText(el.textContent).then(() => {"
a "    const btn = el.closest('.modal').querySelector('.modal-btn');"
a "    const orig = btn.textContent;"
a "    btn.textContent = 'Copied!';"
a "    setTimeout(() => btn.textContent = orig, 1500);"
a "  });"
a "}"
a "function showTab(id) {"
a "  document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));"
a "  document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));"
a "  document.getElementById(id).classList.add('active');"
a "  document.querySelector('[data-tab=\"' + id + '\"]').classList.add('active');"
a "  location.hash = id;"
a "}"
a "(function() {"
a "  var saved = location.hash.replace('#', '');"
a "  if (saved && document.getElementById(saved)) showTab(saved);"
a "})();"
a "document.addEventListener('keydown', e => { if (e.key === 'Escape') document.querySelectorAll('.modal-overlay.active').forEach(m => m.classList.remove('active')); });"
a "setInterval(() => { if (!document.querySelector('.modal-overlay.active')) location.reload(); }, 5000);"
a "</script>"

a "</body>"
a "</html>"

File.WriteAllText(reportOutputPath, sb.ToString())
printfn "Report written to %s" reportOutputPath
