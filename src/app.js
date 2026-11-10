'use strict';

const express = require('express');
const { createStore } = require('./store');
const { accountsRouter } = require('./routes/accounts');
const { productsRouter } = require('./routes/products');

function createApp({ store = createStore() } = {}) {
  const app = express();
  app.use(express.json());

  app.get('/health', (req, res) => res.json({ status: 'ok' }));
  app.use('/api/auth', accountsRouter(store));
  app.use('/api/products', productsRouter(store));

  app.use((req, res) => res.status(404).json({ error: 'Not found' }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    if (err.type === 'entity.parse.failed') {
      return res.status(400).json({ error: 'Request body must be valid JSON' });
    }
    console.error(err);
    return res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}

module.exports = { createApp };
