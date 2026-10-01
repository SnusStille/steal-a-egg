import { cp, mkdir, rm } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const websiteDirectory = resolve(scriptDirectory, "..");
const outputDirectory = resolve(websiteDirectory, "dist");
const publicFiles = ["index.html", "styles.css", "script.js", "favicon.svg", "robots.txt"];

await rm(outputDirectory, { recursive: true, force: true });
await mkdir(outputDirectory, { recursive: true });

for (const file of publicFiles) {
  await cp(resolve(websiteDirectory, file), resolve(outputDirectory, file));
}

await cp(resolve(websiteDirectory, "assets"), resolve(outputDirectory, "assets"), {
  recursive: true,
  filter: (source) => !source.endsWith("README.md")
});

if (process.env.SITE_URL) {
  const sitemapScript = resolve(scriptDirectory, "generate-sitemap.mjs");
  const result = spawnSync(process.execPath, [sitemapScript, process.env.SITE_URL, "dist"], { stdio: "inherit" });
  if (result.status !== 0) process.exit(result.status || 1);
} else {
  console.log("SITE_URL not set; build is ready, but sitemap is skipped until the production domain is known.");
}

console.log(`Built static site to ${outputDirectory}`);
