'use strict';

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../src/app');

let server;
let baseUrl;

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(() => new Promise((resolve) => server.close(resolve)));

async function call(method, path, { body, token } = {}) {
  const headers = {};
  if (body !== undefined) headers['content-type'] = 'application/json';
  if (token) headers.authorization = `Bearer ${token}`;
  const res = await fetch(baseUrl + path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  return { status: res.status, body: text ? JSON.parse(text) : undefined };
}

let counter = 0;
async function signedInUser() {
  counter += 1;
  const email = `user${counter}@example.com`;
  const password = 'correct-horse';
  await call('POST', '/api/auth/register', { body: { email, password } });
  const login = await call('POST', '/api/auth/login', { body: { email, password } });
  return login.body.token;
}

describe('accounts', () => {
  test('register returns the account without the password', async () => {
    const res = await call('POST', '/api/auth/register', {
      body: { email: 'Alice@Example.com', password: 'secret-pass' },
    });
    assert.equal(res.status, 201);
    assert.equal(res.body.email, 'alice@example.com');
    assert.ok(res.body.id);
    assert.equal(res.body.password, undefined);
    assert.equal(res.body.passwordHash, undefined);
  });

  test('an email can be registered only once', async () => {
    const body = { email: 'bob@example.com', password: 'secret-pass' };
    assert.equal((await call('POST', '/api/auth/register', { body })).status, 201);
    const again = await call('POST', '/api/auth/register', {
      body: { ...body, email: 'BOB@example.com' },
    });
    assert.equal(again.status, 409);
  });

  test('register rejects invalid email and short password', async () => {
    const badEmail = await call('POST', '/api/auth/register', { body: { email: 'nope', password: 'secret-pass' } });
    assert.equal(badEmail.status, 400);
    const shortPw = await call('POST', '/api/auth/register', { body: { email: 'c@example.com', password: 'short' } });
    assert.equal(shortPw.status, 400);
  });

  test('sign in with the registered email and password', async () => {
    await call('POST', '/api/auth/register', { body: { email: 'dana@example.com', password: 'secret-pass' } });
    const res = await call('POST', '/api/auth/login', { body: { email: 'dana@example.com', password: 'secret-pass' } });
    assert.equal(res.status, 200);
    assert.ok(res.body.token);
    assert.equal(res.body.user.email, 'dana@example.com');
    assert.equal(res.body.user.passwordHash, undefined);
  });

  test('sign in fails with a wrong password or unknown email', async () => {
    await call('POST', '/api/auth/register', { body: { email: 'erin@example.com', password: 'secret-pass' } });
    const wrong = await call('POST', '/api/auth/login', { body: { email: 'erin@example.com', password: 'wrong-pass' } });
    assert.equal(wrong.status, 401);
    const unknown = await call('POST', '/api/auth/login', { body: { email: 'nobody@example.com', password: 'secret-pass' } });
    assert.equal(unknown.status, 401);
  });
});

describe('catalog', () => {
  const product = { name: 'Mug', description: 'Ceramic mug', price: 12.5, code: 'MUG-001' };

  test('adding a product requires sign-in', async () => {
    const noToken = await call('POST', '/api/products', { body: product });
    assert.equal(noToken.status, 401);
    const badToken = await call('POST', '/api/products', { body: product, token: 'not-a-token' });
    assert.equal(badToken.status, 401);
  });

  test('a signed-in user adds a product, anyone can view it', async () => {
    const token = await signedInUser();
    const created = await call('POST', '/api/products', { body: product, token });
    assert.equal(created.status, 201);
    assert.ok(created.body.id);
    assert.equal(created.body.code, 'MUG-001');
    assert.equal(created.body.price, 12.5);

    const list = await call('GET', '/api/products');
    assert.equal(list.status, 200);
    assert.ok(list.body.some((p) => p.id === created.body.id));

    const one = await call('GET', `/api/products/${created.body.id}`);
    assert.equal(one.status, 200);
    assert.equal(one.body.name, 'Mug');
  });

  test('a product code can be used only once', async () => {
    const token = await signedInUser();
    const body = { ...product, code: 'DUP-1' };
    assert.equal((await call('POST', '/api/products', { body, token })).status, 201);
    assert.equal((await call('POST', '/api/products', { body: { ...body, name: 'Other' }, token })).status, 409);
  });

  test('product fields are validated', async () => {
    const token = await signedInUser();
    const res = await call('POST', '/api/products', { body: { name: 'X', price: -1 }, token });
    assert.equal(res.status, 400);
    assert.ok(res.body.details.length >= 3);
  });

  test('an unknown product id returns 404', async () => {
    const res = await call('GET', '/api/products/does-not-exist');
    assert.equal(res.status, 404);
  });
});
