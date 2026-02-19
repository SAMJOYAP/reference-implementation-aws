import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

test("index.html contains app name", () => {
  const html = readFileSync("public/index.html", "utf8");
  assert.equal(html.includes("${{ values.name }}"), true);
});
