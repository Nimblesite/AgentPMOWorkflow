// Build-time GitHub Releases data file. Implements [WEB-RELEASES].
//
// Eleventy runs this during the static build and bakes the result into the
// /releases/ page and the homepage — the browser makes ZERO network calls.
// Customize REPO for the target repository (or read it from an env var).
//
// Requires a `releaseNotes` Markdown filter registered in eleventy.config.js
// with raw HTML DISABLED — release notes carry untrusted PR titles/handles:
//
//   import markdownIt from "markdown-it";
//   const md = markdownIt({ html: false, linkify: true });
//   eleventyConfig.addFilter("releaseNotes", (b) => (b ? md.render(b) : ""));

const REPO = "{{REPO_OWNER}}/{{REPO_NAME}}";
// Full set powers the /releases/ page; the homepage shows `recent` only.
const MAX_RELEASES = 30;
const RECENT_COUNT = 4;
const API_URL = `https://api.github.com/repos/${REPO}/releases?per_page=${MAX_RELEASES}`;
const RELEASES_URL = `https://github.com/${REPO}/releases`;

function fallback(reason) {
  if (reason) console.warn(`[_data/release] using fallback — ${reason}`);
  return {
    available: false,
    tag: null,
    version: null,
    url: RELEASES_URL,
    releasesUrl: RELEASES_URL,
    publishedAt: null,
    publishedDate: null,
    items: [],
    recent: [],
  };
}

function versionFromTag(tag) {
  if (!tag) return null;
  return tag.startsWith("v") ? tag.slice(1) : tag;
}

function formatDate(value) {
  if (!value) return null;
  return new Intl.DateTimeFormat("en", { dateStyle: "medium", timeZone: "UTC" }).format(
    new Date(value),
  );
}

function mapRelease(data) {
  const tag = data.tag_name;
  const publishedAt = data.published_at || null;
  return {
    tag,
    version: versionFromTag(tag),
    title: data.name || tag,
    url: data.html_url || RELEASES_URL,
    publishedAt,
    publishedDate: formatDate(publishedAt),
    prerelease: Boolean(data.prerelease),
    // Raw Markdown notes — rendered by the `releaseNotes` filter (html:false).
    body: data.body || "",
  };
}

export default async function () {
  if (process.env.SKIP_RELEASE_FETCH === "1") {
    return fallback("SKIP_RELEASE_FETCH=1");
  }

  const headers = {
    "User-Agent": "{{REPO_NAME}}-website-build",
    Accept: "application/vnd.github+json",
  };
  const token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN;
  if (token) {
    headers.Authorization = `Bearer ${token}`;
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);
    const response = await fetch(API_URL, { headers, signal: controller.signal });
    clearTimeout(timeoutId);

    if (!response.ok) {
      return fallback(`GitHub API responded ${response.status}`);
    }

    const data = await response.json();
    const items = data.filter((item) => !item.draft).map(mapRelease);
    const latest = items.find((item) => !item.prerelease) || items[0];
    if (!latest) {
      return fallback("response missing releases");
    }

    return {
      available: true,
      tag: latest.tag,
      version: latest.version,
      url: latest.url,
      releasesUrl: RELEASES_URL,
      publishedAt: latest.publishedAt,
      publishedDate: latest.publishedDate,
      items,
      recent: items.slice(0, RECENT_COUNT),
    };
  } catch (err) {
    return fallback(err.message);
  }
}
