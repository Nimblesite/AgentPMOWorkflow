import { EleventyHtmlBasePlugin } from "@11ty/eleventy";

export default function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy("src/assets");
  // Custom domain for GitHub Pages — must land at the site root so the
  // Actions deploy keeps agentpmo.dev pinned on every build.
  eleventyConfig.addPassthroughCopy("src/CNAME");

  eleventyConfig.addPlugin(EleventyHtmlBasePlugin);

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
