# Dev environment container: runs the F# report on a cron schedule
# using supercronic. Templates and enforce-repo-standards skill included.
#
# Build context: project_status root

FROM mcr.microsoft.com/dotnet/sdk:8.0

# Install system dependencies: git, curl, Node.js, gh CLI
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    gnupg \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install gh CLI
RUN mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (LTS) for Playwright tests if needed
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install supercronic
ARG SUPERCRONIC_VERSION=v0.2.33
ARG SUPERCRONIC_ARCH=amd64
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/${SUPERCRONIC_VERSION}/supercronic-linux-${SUPERCRONIC_ARCH}
RUN curl -fsSLO "${SUPERCRONIC_URL}" \
    && chmod +x "supercronic-linux-${SUPERCRONIC_ARCH}" \
    && mv "supercronic-linux-${SUPERCRONIC_ARCH}" /usr/local/bin/supercronic

# Copy project into image (templates and skill are available at build time)
COPY . /workspaces/project_status

# Create output directory
RUN mkdir -p /output

# Create the crontab: run project_status every 5 minutes
RUN echo '*/5 * * * * dotnet fsi /workspaces/project_status/dashboard/repo-report.fsx >> /output/repo-report.log 2>> /output/repo-report-debug.log' \
    > /etc/supercronic-crontab

# Environment variables (all overridable at runtime via docker-compose / .env)
ENV REPOS_PATH=/workspaces \
    REPORT_OUTPUT_PATH=/output/repo-report.html \
    REPO_BOOTSTRAP_PATH=/workspaces/project_status \
    TZ=UTC

# See docker-compose.yml for volume definitions

CMD ["supercronic", "/etc/supercronic-crontab"]
