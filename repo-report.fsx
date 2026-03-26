open System
open System.IO
open System.Diagnostics
open System.Text

let resolveCmd (cmd: string) =
    let paths = [| "/opt/homebrew/bin"; "/usr/local/bin"; "/usr/bin"; "/bin" |]
    match paths |> Array.tryFind (fun p -> File.Exists(Path.Combine(p, cmd))) with
    | Some p -> Path.Combine(p, cmd)
    | None -> cmd

let run cmd args workDir =
    let resolved = resolveCmd cmd
    eprintfn "[CMD] %s %s (in %s)" resolved args workDir
    try
        let psi = ProcessStartInfo(fileName = resolved, arguments = (args: string))
        psi.WorkingDirectory <- workDir
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        psi.UseShellExecute <- false
        psi.CreateNoWindow <- true
        let p = Process.Start(psi)
        let output = p.StandardOutput.ReadToEnd()
        let stderr = p.StandardError.ReadToEnd()
        p.WaitForExit(15000) |> ignore
        let result = output.Trim()
        eprintfn "[OUT] %s" (if result.Length > 200 then result.[0..199] + "..." else result)
        if not (String.IsNullOrWhiteSpace(stderr)) then
            eprintfn "[ERR] %s" (stderr.Trim())
        result
    with ex ->
        eprintfn "[EXCEPTION] %s: %s" cmd (ex.Message)
        ""

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
    eprintfn "[PR] Looking for open PR with --head %s in %s" currentBranch (Path.GetFileName(dir))
    let headArg = "--head " + currentBranch
    let title = run "gh" ("pr list --state open " + headArg + " --json title --limit 1 --jq .[0].title") dir
    let branch = run "gh" ("pr list --state open " + headArg + " --json headRefName --limit 1 --jq .[0].headRefName") dir
    let t = if String.IsNullOrWhiteSpace(title) || title = "null" then "" else title
    let b = if String.IsNullOrWhiteSpace(branch) || branch = "null" then "" else branch
    eprintfn "[PR] Result: title='%s' branch='%s'" t b
    (t, b)

let getCIStatus (dir: string) (hasPR: bool) =
    if not hasPR then
        eprintfn "[CI] Skipping CI for %s (no PR)" (Path.GetFileName(dir))
        ("", "")
    else
        eprintfn "[CI] Checking PR checks for %s" (Path.GetFileName(dir))
        let status = run "gh" "pr checks --json state --jq .[0].state" dir
        let date = run "gh" "pr checks --json startedAt --jq .[0].startedAt" dir
        let dateShort = if date.Length >= 16 then date.[0..15].Replace("T", " ") else date
        let s = if String.IsNullOrWhiteSpace(status) || status = "null" then "" else status
        eprintfn "[CI] Result: status='%s' date='%s'" s dateShort
        (s, dateShort)

let escape (s: string) =
    s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")

let scriptDir =
    let s = __SOURCE_DIRECTORY__
    if String.IsNullOrWhiteSpace(s) then Directory.GetCurrentDirectory() else s
let parentDir = Directory.GetParent(scriptDir).FullName

printfn "Scanning repos in %s..." parentDir

let allDirs = Directory.GetDirectories(parentDir) |> Array.filter isGitRepo

printfn "Found %d git repos" allDirs.Length

// Pick top 20 by filesystem last write time, then scan only those
let dirs =
    allDirs
    |> Array.sortByDescending (fun dir -> Directory.GetLastWriteTimeUtc(dir))
    |> Array.truncate 20

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
        let openPR, prBranch = getOpenPR dir branch
        let ciStatus, ciDate = getCIStatus dir (openPR <> "")
        { Name = name; FolderModified = folderMod; ModifiedCount = modCount; LastEdit = lastEdit
          Branch = branch; PRBranch = prBranch; PushStatus = pushStatus; OpenPR = openPR
          CIStatus = ciStatus; CIDate = ciDate }
    )
    |> Array.sortByDescending (fun r -> r.FolderModified)

printfn "\nBuilding report for %d repos..." repos.Length

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
a "</style>"
a "</head>"
a "<body>"
a "<h1>Repo Report</h1>"

let metaLine = "<p class=\"meta\">Generated: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm") + " &nbsp;|&nbsp; Repos with changes: " + string repos.Length + "</p>"
a metaLine

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
        a ("<td>" + escape r.OpenPR + "</td>")
        a ("<td class=\"" + ciClass + "\">" + escape r.CIStatus + "</td>")
        a ("<td>" + escape r.CIDate + "</td>")
        a "</tr>"

    a "</tbody>"
    a "</table>"

a "</body>"
a "</html>"

let outputPath = Path.Combine(scriptDir, "repo-report.html")
File.WriteAllText(outputPath, sb.ToString())
printfn "Report written to %s" outputPath
