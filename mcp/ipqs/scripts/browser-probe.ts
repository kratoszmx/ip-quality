import {probeBrowserAuth} from "../src/browser.js";

try {
  if (process.argv.length > 3 || process.argv[2] && process.argv[2] !== "--headless") throw new Error("invalid-arguments");
  const value = await probeBrowserAuth({ headless: process.argv[2] === "--headless" });
  console.log(JSON.stringify({authenticated: value.authenticated, stage: value.stage}));
  process.exitCode = value.authenticated ? 0 : 1;
} catch {
  console.log(JSON.stringify({authenticated: false, stage: "unavailable"}));
  process.exitCode = 1;
}
