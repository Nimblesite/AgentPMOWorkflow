import { EleventyHtmlBasePlugin } from "@11ty/eleventy";
import techdoc from "eleventy-plugin-techdoc";

export default function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy("src/assets");
  // Custom domain for GitHub Pages — must land at the site root so the
  // Actions deploy keeps agentpmo.dev pinned on every build.
  eleventyConfig.addPassthroughCopy("src/CNAME");

  eleventyConfig.addPlugin(EleventyHtmlBasePlugin);

  // Nimblesite house theme. This is a bespoke marketing site, so the heavy
  // features (blog/docs/api layouts, i18n) stay OFF — we keep our own base.njk
  // layout and CSS. The plugin owns the SEO files (sitemap.xml, robots.txt,
  // feed.xml, llms.txt) and provides structural CSS under /techdoc/.
  eleventyConfig.addPlugin(techdoc, {
    site: {
      name: "Agent PMO",
      url: process.env.SITE_URL || "https://agentpmo.dev",
      description:
        "A set of templates and a skill that convert an existing repo into a standardized, deployable Agent PMO workspace behind enforced quality gates.",
    },
    features: { blog: false, docs: false, darkMode: false, i18n: false },
    i18n: { defaultLanguage: "en", languages: ["en"] },
  });

  eleventyConfig.addFilter("isoDate", (date) => {
    if (!date) return new Date().toISOString().substring(0, 10);
    if (date instanceof Date) return date.toISOString().substring(0, 10);
    return new Date(date).toISOString().substring(0, 10);
  });

  return {
    dir: {
      input: "src",
      output: "_site",
      includes: "_includes",
      data: "_data",
    },
    pathPrefix: process.env.ELEVENTY_PATH_PREFIX || "/",
  };
}
