import { createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { basename, extname, isAbsolute, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const projectDirectory = fileURLToPath(new URL(".", import.meta.url));
const requestedRoot = process.argv[2] || ".";
const rootDirectory = resolve(projectDirectory, requestedRoot);
const port = Number.parseInt(process.env.PORT || "5173", 10);
const host = process.env.HOST || "0.0.0.0";

const mimeTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".mjs", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".svg", "image/svg+xml"],
  [".webp", "image/webp"],
  [".png", "image/png"],
  [".jpg", "image/jpeg"],
  [".jpeg", "image/jpeg"],
  [".xml", "application/xml; charset=utf-8"],
  [".txt", "text/plain; charset=utf-8"],
  [".zip", "application/zip"]
]);

try {
  if (!statSync(rootDirectory).isDirectory()) throw new Error("not a directory");
} catch {
  console.error(`Cannot serve directory: ${rootDirectory}`);
  process.exit(1);
}

const server = createServer((request, response) => {
  if (request.method !== "GET" && request.method !== "HEAD") {
    response.writeHead(405, { "Allow": "GET, HEAD", "Content-Type": "text/plain; charset=utf-8" });
    response.end("Method not allowed");
    return;
  }

  let pathname;
  try {
    pathname = decodeURIComponent(new URL(request.url || "/", "http://localhost").pathname);
  } catch {
    response.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Bad request");
    return;
  }

  let filePath = resolve(rootDirectory, `.${pathname}`);
  const relativePath = relative(rootDirectory, filePath);
  if (relativePath.startsWith("..") || isAbsolute(relativePath)) {
    response.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Forbidden");
    return;
  }

  try {
    if (statSync(filePath).isDirectory()) filePath = resolve(filePath, "index.html");
    const fileInfo = statSync(filePath);
    if (!fileInfo.isFile()) throw new Error("not a file");

    const extension = extname(filePath).toLowerCase();
    const responseHeaders = {
      "Content-Type": mimeTypes.get(extension) || "application/octet-stream",
      "Content-Length": fileInfo.size,
      "Last-Modified": fileInfo.mtime.toUTCString(),
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff"
    };
    if (extension === ".zip") {
      responseHeaders["Content-Disposition"] = `attachment; filename="${basename(filePath)}"`;
    }
    response.writeHead(200, responseHeaders);
    if (request.method === "HEAD") {
      response.end();
      return;
    }
    createReadStream(filePath).pipe(response);
  } catch {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" });
    response.end("Not found");
  }
});

server.listen(port, host, () => {
  console.log(`MV Riv & Bygg — dev server: http://localhost:${port}`);
  console.log(`Serving: ${rootDirectory}`);
  console.log("Stop server with Ctrl+C.");
});

server.on("error", (error) => {
  console.error(`Dev server error: ${error.message}`);
  process.exitCode = 1;
});
