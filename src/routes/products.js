'use strict';

const express = require('express');
const { requireAuth } = require('../auth');

function validateProduct(body) {
  const errors = [];
  const name = typeof body?.name === 'string' ? body.name.trim() : '';
  const description = typeof body?.description === 'string' ? body.description.trim() : '';
  const code = typeof body?.code === 'string' ? body.code.trim() : '';
  const price = body?.price;

  if (!name) errors.push('name is required');
  if (!description) errors.push('description is required');
  if (!code) errors.push('code is required');
  if (typeof price !== 'number' || !Number.isFinite(price) || price < 0) {
    errors.push('price must be a non-negative number');
  }
  return { errors, product: { name, description, price, code } };
}

function productsRouter(store) {
  const router = express.Router();

  // Browsing is open to everyone.
  router.get('/', (req, res) => {
    res.json(store.listProducts());
  });

  router.get('/:id', (req, res) => {
    const product = store.findProductById(req.params.id);
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    return res.json(product);
  });

  // Catalog changes require sign-in.
  router.post('/', requireAuth(store), (req, res) => {
    const { errors, product } = validateProduct(req.body);
    if (errors.length) {
      return res.status(400).json({ error: 'Invalid product', details: errors });
    }
    const created = store.addProduct({ ...product, createdBy: req.user.id });
    if (!created) {
      return res.status(409).json({ error: 'A product with this code already exists' });
    }
    return res.status(201).json(created);
  });

  return router;
}

module.exports = { productsRouter };
