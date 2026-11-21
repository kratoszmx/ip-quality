import { manualLogin } from "../src/browser.js";

console.log("Opening IPQS in a window of the shared Chrome profile (the text browser's saved profile).");
console.log("Complete login only in the visible browser; do not paste credentials into this terminal.");
console.log(JSON.stringify(await manualLogin(), null, 2));
