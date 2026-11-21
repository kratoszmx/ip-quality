import { inspectNativeVerification } from '@myutils/web-text/verification/activation';

// Normal site verification on an account-owned page. The shared text browser
// owns checkbox discovery and native input; this module owns the account origin,
// one activation and bounded settling. Clearing a check is not login proof.
export async function prepareBrowserVerification(page, origin, timeoutMs = 8000, dependencies = {}) {
  if (new URL(origin).origin !== origin || !origin.startsWith('https://')
    || !Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 30000) throw Error('Invalid verification scope.');
  const belongs = value => {
    try { const url = new URL(value); return url.origin === origin && !url.username && !url.password; }
    catch { return false; }
  };
  const inspect = dependencies.inspect || inspectNativeVerification;
  const now = dependencies.now || Date.now;
  const pause = dependencies.pause || (milliseconds => page.waitForTimeout(milliseconds));
  const deadline = now() + timeoutMs;
  const activation = { attempted: false, clicked: false };
  let encountered = false;
  for (;;) {
    if (!belongs(page.url())) throw Error('Verification left the account origin.');
    let pending;
    try {
      pending = await page.evaluate(() => {
        const responses = [...document.querySelectorAll('input[name="cf_challenge_response"],input[name="cf-turnstile-response"]')];
        if (responses.length) return responses.some(input => !input.value);
        return /verify (?:that )?you are human|let us know you are human|checking your browser|performing security verification|正在執行安全驗證|正在进行安全验证/i
          .test((document.body?.innerText || '').slice(0, 30000)) || /^(?:Just a moment|請稍候|请稍候)/i.test(document.title);
      });
    } catch (error) {
      // The site's normal verification return can replace the document.
      // Observe the same owned page again; never interpret that race as success.
      if (!/Execution context was destroyed|Cannot find context/i.test(error.message)) throw error;
      if (now() >= deadline) return { encountered, pending: true, ...activation };
      await pause(Math.min(250, deadline - now()));
      continue;
    }
    encountered ||= pending;
    if (!pending || now() >= deadline) return { encountered, pending, ...activation };
    if (!activation.attempted) await inspect(page, activation);
    if (now() >= deadline) return { encountered, pending: true, ...activation };
    await pause(Math.min(250, deadline - now()));
  }
}
