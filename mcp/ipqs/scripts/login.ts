import { manualLogin } from "../src/browser.js";

console.log("Opening IPQS in a dedicated real Chrome/CDP profile.");
console.log("Complete login only in the visible browser; do not paste credentials into this terminal.");
console.log(JSON.stringify(await manualLogin(), null, 2));
