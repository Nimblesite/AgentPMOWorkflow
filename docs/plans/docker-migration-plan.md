# Docker Dev Environment Setup

A polyglot dev container with `mise` for runtimes. `project_status` and `repo_bootstrap` run inside it. A separate scheduler container runs `project_status` every 5 minutes via Supercronic. VS Code attaches to the running container and opens any folder.

---

## Step 1: Create the Project Structure

```
~/DockerDev/
├── compose.yaml
├── Dockerfile.dev
├── .mise.toml
├── .env
├── .env.example
├── .gitignore
└── repos/
    ├── project_status/
    │   ├── Dockerfile.scheduler
    │   ├── crontab
    │   └── project_status.fsx
    └── repo_bootstrap/
```

**.env.example:**
```bash
GH_TOKEN=ghp_your_token_here
GH_USER=your_github_username
TZ=America/New_York
```

Copy to `.env` and fill in real values. `.env` is gitignored.

---

## Step 2: Parameterize project_status and repo_bootstrap

1. `grep -rn "/Users/" project_status.fsx` to find hardcoded paths
2. Replace all hardcoded paths with:
   ```fsharp
   let repoBasePath =
       Environment.GetEnvironmentVariable("REPO_BASE_PATH")
       |> Option.ofObj
       |> Option.defaultValue "/workspaces"
   ```
3. Replace hardcoded GitHub username with:
   ```fsharp
   let ghUser =
       Environment.GetEnvironmentVariable("GH_USER")
       |> Option.ofObj
       |> Option.defaultWith (fun () ->
           let proc = System.Diagnostics.Process.Start(
               System.Diagnostics.ProcessStartInfo(
                   FileName = "gh",
                   Arguments = "api user --jq .login",
                   UseShellExecute = false,
                   RedirectStandardOutput = true))
           proc.StandardOutput.ReadToEnd().Trim())
   ```
4. Do the same for `repo_bootstrap`
5. Test locally:
   ```bash
   GH_TOKEN=$(gh auth token) GH_USER=$(gh api user --jq '.login') dotnet fsi project_status.fsx
   ```

---

## Step 3: Create Dockerfile.dev

**.mise.toml:**
```toml
[tools]
node = "20"
python = "3.12"
rust = "latest"
dotnet = "9.0"

[env]
REPO_BASE_PATH = "/workspaces"
```

**Dockerfile.dev:**
```dockerfile
FROM buildpack-deps:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip zip ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/*

RUN curl https://mise.jdx.dev/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

COPY .mise.toml /root/.mise.toml
RUN mise install --yes

RUN (type -p wget >/dev/null || apt-get install wget -y) \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install gh -y \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/dart.gpg \
    && echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/dart-archive/channels/stable/release/latest/linux_packages stable main' \
       | tee /etc/apt/sources.list.d/dart_stable.list \
    && apt-get update && apt-get install -y dart \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/lib/dart/bin:${PATH}"

WORKDIR /workspaces
CMD ["sleep", "infinity"]
```

Build it: `docker build -f Dockerfile.dev -t devbox .`

---

## Step 4: Create the Scheduler

**repos/project_status/Dockerfile.scheduler:**
```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:9.0-alpine

RUN apk add --no-cache curl ca-certificates github-cli

ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.33/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64

RUN curl -fsSLO "$SUPERCRONIC_URL" \
    && chmod +x "$SUPERCRONIC" \
    && mv "$SUPERCRONIC" /usr/local/bin/supercronic

WORKDIR /scripts
COPY project_status.fsx .
COPY crontab /etc/crontab

CMD ["supercronic", "/etc/crontab"]
```

**repos/project_status/crontab:**
```cron
*/5 * * * * /usr/bin/dotnet fsi /scripts/project_status.fsx 2>&1
```

---

## Step 5: Create compose.yaml

```yaml
services:

  devbox:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - ./repos:/workspaces:cached
      - cargo-registry:/root/.cargo/registry
      - cargo-git:/root/.cargo/git
      - nuget-cache:/root/.nuget
      - pub-cache:/root/.pub-cache
      - ~/.gitconfig:/root/.gitconfig:ro
      - ~/.config/gh:/root/.config/gh:ro
    environment:
      - GH_TOKEN=${GH_TOKEN}
      - GH_USER=${GH_USER}
      - REPO_BASE_PATH=/workspaces
      - TZ=${TZ:-America/New_York}
    ports:
      - "3000-3010:3000-3010"
      - "5000-5005:5000-5005"
      - "8080-8085:8080-8085"
    restart: unless-stopped
    stdin_open: true
    tty: true

  scheduler:
    build:
      context: ./repos/project_status
      dockerfile: Dockerfile.scheduler
    volumes:
      - ./repos/project_status:/scripts:ro
      - scheduler-output:/output
    environment:
      - GH_TOKEN=${GH_TOKEN}
      - GH_USER=${GH_USER}
      - OUTPUT_DIR=/output
      - TZ=${TZ:-America/New_York}
    restart: unless-stopped

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-devpass}
    volumes:
      - pgdata:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    profiles:
      - database

volumes:
  cargo-registry:
  cargo-git:
  nuget-cache:
  pub-cache:
  pgdata:
  scheduler-output:
```

Bring it up: `docker compose up -d`

---

## Step 6: VS Code Setup

1. Install the "Dev Containers" extension
2. `Cmd+Shift+P` -> `Dev Containers: Attach to Running Container` -> select devbox
3. `File -> Open Folder` -> `/workspaces/project_status`
4. Open another window, attach again, open `/workspaces/repo_bootstrap`

Create `~/.config/Code/User/globalStorage/ms-vscode-remote.remote-containers/nameConfigs/<container-name>.json` so extensions persist:
```json
{
  "extensions": ["rust-lang.rust-analyzer", "ms-python.python", "ms-dotnettools.csharp", "Dart-Code.dart-code", "Ionide.Ionide-fsharp"],
  "workspaceFolder": "/workspaces"
}
```

---

## Step 7: Publish as Open Source

1. Clean git history:
   ```bash
   pip install git-filter-repo
   git filter-repo --replace-text <(echo '/Users/christian/==>$HOME/')
   git filter-repo --invert-paths --path secrets.json
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force
   ```
2. Add to each repo: `README.md`, `LICENSE` (MIT), `.github/workflows/ci.yml`
3. Set GitHub topics: `cli`, `developer-tools`, `f-sharp`, `dotnet`, `github`
4. `gh release create v1.0.0 --generate-notes`

---

## Step 8: Verify

1. `docker compose down -v && docker compose up -d`
2. Attach VS Code to devbox, open project_status and repo_bootstrap
3. Run `git pull` and `gh auth status` inside the container
4. `docker compose logs -f scheduler` -- confirm project_status runs every 5 minutes

---

## Quick Reference

```bash
docker compose up -d                                      # Start
docker compose exec devbox bash                           # Shell in
docker compose logs -f scheduler                          # Scheduler logs
docker compose build devbox && docker compose up -d devbox  # Rebuild
docker compose down                                       # Stop
```

VS Code: `Cmd+Shift+P` -> `Attach to Running Container` -> devbox -> Open Folder -> `/workspaces/<project>`
