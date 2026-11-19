import assert from 'node:assert/strict';
import test from 'node:test';
import { runInNewContext } from 'node:vm';
import { prepareBrowserVerification } from '../../common/verification.mjs';

const origin = 'https://account.example';

test('normal checkbox preparation clears a check without claiming account authentication', async () => {
  let pending = true, clock = 0, inspections = 0;
  const page = { url: () => origin + '/login', evaluate: async () => pending };
  const result = await prepareBrowserVerification(page, origin, 1000, {
    now: () => clock, pause: async ms => { clock += ms; },
    inspect: async (_page, policy, activation) => {
      inspections++;
      assert.equal(policy.navigationAllowed(origin + '/login'), true);
      assert.equal(policy.navigationAllowed('https://foreign.invalid/login'), false);
      assert.equal(policy.frameNavigationAllowed('https://challenges.cloudflare.com/cdn-cgi/challenge-platform/widget'), true);
      assert.equal(policy.frameNavigationAllowed('https://challenges.cloudflare.com/account'), false);
      assert.equal(policy.frameNavigationAllowed('https://foreign.invalid/cdn-cgi/challenge-platform/widget'), false);
      activation.attempted = true; activation.clicked = true; activation.input = 'dispatched';
      pending = false;
    },
  });
  assert.deepEqual(result, { encountered: true, pending: false, attempted: true, clicked: true, input: 'dispatched' });
  assert.equal(inspections, 1);
  assert.equal(Object.hasOwn(result, 'authenticated'), false);
});

test('unresolved or unacknowledged verification stays pending and sends at most one input', async () => {
  for (const clicked of [true, false]) {
    let clock = 0, attempts = 0;
    const result = await prepareBrowserVerification({ url: () => origin, evaluate: async () => true }, origin, 600, {
      now: () => clock, pause: async ms => { clock += ms; },
      inspect: async (_page, _policy, activation) => {
        attempts++; activation.attempted = true; activation.clicked = clicked;
        activation.input = clicked ? 'dispatched' : 'unknown';
      },
    });
    assert.equal(result.pending, true);
    assert.equal(attempts, 1);
    assert.equal(clock, 600);
  }
});

test('completed response fields and an ordinary page do not cause another verification click', async () => {
  for (const [text, title, responses, expected] of [
    ['Sign in', 'Account', [], false],
    ['Verify you are human', 'Account', [{ value: 'synthetic-private-response' }], false],
    ['Verify you are human', 'Account', [{ value: '' }], true],
    ['Loading', 'Just a moment...', [], true],
  ]) {
    const page = { url: () => origin, evaluate: async project => runInNewContext(`(${project.toString()})()`, {
      document: { title, body: { innerText: text }, querySelectorAll: () => responses },
    }) };
    const result = await prepareBrowserVerification(page, origin, 1, {
      now: (() => { let clock = 0; return () => clock++; })(),
      inspect: async () => assert.fail('No input is allowed after this deadline.'),
    });
    assert.equal(result.pending, expected);
    assert.equal(JSON.stringify(result).includes('synthetic-private-response'), false);
  }
});

test('foreign navigation and invalid deadlines stop before page inspection or native input', async () => {
  const page = { url: () => 'https://foreign.invalid/login', evaluate: async () => assert.fail('Foreign page inspected') };
  await assert.rejects(prepareBrowserVerification(page, origin), /account origin/);
  for (const timeout of [0, -1, 30001, NaN])
    await assert.rejects(prepareBrowserVerification(page, origin, timeout), /scope/);
});

test('a normal verification document replacement settles within the original deadline', async () => {
  let reads = 0, clock = 0;
  const page = { url: () => origin, evaluate: async () => {
    reads++; if (reads === 1) throw Error('Execution context was destroyed due to navigation'); return false;
  } };
  const result = await prepareBrowserVerification(page, origin, 500, {
    now: () => clock, pause: async ms => { clock += ms; },
    inspect: async () => assert.fail('The completed page needs no input'),
  });
  assert.equal(result.pending, false);
  assert.equal(reads, 2);
  assert.equal(clock, 250);
  page.evaluate = async () => { throw Error('browser closed'); };
  await assert.rejects(prepareBrowserVerification(page, origin), /browser closed/);
});
