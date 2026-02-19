import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

test("express server file exists and contains /healthz route", () => {
  const code = readFileSync("server/index.mjs", "utf8");
  assert.equal(code.includes("/healthz"), true);
});
