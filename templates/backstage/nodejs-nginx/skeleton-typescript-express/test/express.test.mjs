import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

test("typescript express server exists and contains /healthz route", () => {
  const code = readFileSync("server/index.ts", "utf8");
  assert.equal(code.includes("/healthz"), true);
});
