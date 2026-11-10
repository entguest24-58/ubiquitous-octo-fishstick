'use strict';

const express = require('express');
const { hashPassword, verifyPassword } = require('../passwords');

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MIN_PASSWORD_LENGTH = 8;

// Never includes the password or its hash.
function publicUser(user) {
  return { id: user.id, email: user.email, createdAt: user.createdAt };
}

function readCredentials(body) {
  const email = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : '';
  const password = typeof body?.password === 'string' ? body.password : '';
  return { email, password };
}

function accountsRouter(store) {
  const router = express.Router();

  router.post('/register', async (req, res, next) => {
    try {
      const { email, password } = readCredentials(req.body);
      if (!EMAIL_PATTERN.test(email)) {
        return res.status(400).json({ error: 'A valid email is required' });
      }
      if (password.length < MIN_PASSWORD_LENGTH) {
        return res.status(400).json({ error: `Password must be at least ${MIN_PASSWORD_LENGTH} characters` });
      }
      if (store.findUserByEmail(email)) {
        return res.status(409).json({ error: 'An account with this email already exists' });
      }
      const passwordHash = await hashPassword(password);
      const user = store.addUser({ email, passwordHash });
      if (!user) {
        return res.status(409).json({ error: 'An account with this email already exists' });
      }
      return res.status(201).json(publicUser(user));
    } catch (err) {
      return next(err);
    }
  });

  router.post('/login', async (req, res, next) => {
    try {
      const { email, password } = readCredentials(req.body);
      if (!email || !password) {
        return res.status(400).json({ error: 'Email and password are required' });
      }
      const user = store.findUserByEmail(email);
      if (!user || !(await verifyPassword(password, user.passwordHash))) {
        return res.status(401).json({ error: 'Invalid email or password' });
      }
      const token = store.createSession(user.id);
      return res.status(200).json({ token, user: publicUser(user) });
    } catch (err) {
      return next(err);
    }
  });

  return router;
}

module.exports = { accountsRouter, publicUser };
