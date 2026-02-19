import express from "express";

const app = express();
const port = process.env.PORT || 3000;

app.get("/healthz", (_req, res) => {
  res.json({ status: "ok" });
});

app.get("/api/hello", (_req, res) => {
  res.json({ message: "hello from express" });
});

app.listen(port, () => {
  console.log(`Express API listening on :${port}`);
});
