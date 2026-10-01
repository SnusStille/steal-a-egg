import { mkdir, writeFile } from "node:fs/promises";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const rawSiteUrl = process.argv[2] || process.env.SITE_URL;

if (!rawSiteUrl) {
  console.error("Set SITE_URL to the production site origin before generating SEO files.");
  console.error("Example: node scripts/generate-sitemap.mjs https://your-domain.se");
  process.exit(1);
}

let siteUrl;
try {
  siteUrl = new URL(rawSiteUrl);
} catch {
  console.error(`Invalid SITE_URL: ${rawSiteUrl}`);
  process.exit(1);
}

if (!new Set(["https:", "http:"]).has(siteUrl.protocol)) {
  console.error("SITE_URL must use http or https.");
  process.exit(1);
}

if (siteUrl.search || siteUrl.hash) {
  console.error("SITE_URL should be a site origin or base path, without a query or fragment.");
  process.exit(1);
}

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const websiteDirectory = resolve(scriptDirectory, "..");
const outputDirectory = resolve(websiteDirectory, process.argv[3] || ".");
const outputRelativePath = relative(websiteDirectory, outputDirectory);
if (outputRelativePath.startsWith("..") || isAbsolute(outputRelativePath)) {
  console.error("Output directory must be inside the website project.");
  process.exit(1);
}

const basePath = siteUrl.pathname.replace(/\/+$/, "");
const canonicalUrl = `${siteUrl.origin}${basePath}/`.replace(/&/g, "&amp;");
const sitemapUrl = `${siteUrl.origin}${basePath}/sitemap.xml`;
const lastmod = new Date().toISOString().slice(0, 10);
const sitemap = `<?xml version="1.0" encoding="UTF-8"?>\n` +
  `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
  `  <url>\n` +
  `    <loc>${canonicalUrl}</loc>\n` +
  `    <lastmod>${lastmod}</lastmod>\n` +
  `    <changefreq>monthly</changefreq>\n` +
  `    <priority>1.0</priority>\n` +
  `  </url>\n` +
  `</urlset>\n`;
const robots = `User-agent: *\nAllow: /\n\nSitemap: ${sitemapUrl}\n`;

await mkdir(outputDirectory, { recursive: true });
await Promise.all([
  writeFile(resolve(outputDirectory, "sitemap.xml"), sitemap, "utf8"),
  writeFile(resolve(outputDirectory, "robots.txt"), robots, "utf8")
]);
console.log(`Wrote sitemap.xml and robots.txt for ${canonicalUrl}`);
