import {probeHttpAuth} from "../src/http-auth.js";

try {
  if (process.argv.length !== 2) throw new Error("invalid-arguments");
  const value = await probeHttpAuth();
  console.log(JSON.stringify({authenticated: value.authenticated, stage: value.stage}));
  process.exitCode = value.authenticated ? 0 : 1;
} catch {
  console.log(JSON.stringify({authenticated: false, stage: "unavailable"}));
  process.exitCode = 1;
}
