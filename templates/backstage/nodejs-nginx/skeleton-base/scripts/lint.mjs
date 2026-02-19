import { existsSync } from "node:fs";

const requiredPaths = [
  "public/index.html",
  "Dockerfile",
  "nginx/default.conf",
  "manifests/deployment.yaml",
];

const missing = requiredPaths.filter((p) => !existsSync(p));
if (missing.length > 0) {
  console.error("Missing required files:\n" + missing.join("\n"));
  process.exit(1);
}

console.log("Lint check passed.");
