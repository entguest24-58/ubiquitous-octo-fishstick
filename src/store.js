'use strict';

const crypto = require('node:crypto');

// All data lives in process memory and is lost when the service stops.
function createStore() {
  const usersById = new Map();
  const userIdByEmail = new Map();
  const sessions = new Map(); // token -> userId
  const productsById = new Map();
  const productIdByCode = new Map();

  return {
    findUserByEmail(email) {
      const id = userIdByEmail.get(email);
      return id ? usersById.get(id) : undefined;
    },
    findUserById(id) {
      return usersById.get(id);
    },
    addUser({ email, passwordHash }) {
      if (userIdByEmail.has(email)) return null;
      const user = { id: crypto.randomUUID(), email, passwordHash, createdAt: new Date().toISOString() };
      usersById.set(user.id, user);
      userIdByEmail.set(email, user.id);
      return user;
    },
    createSession(userId) {
      const token = crypto.randomBytes(32).toString('hex');
      sessions.set(token, userId);
      return token;
    },
    userIdForToken(token) {
      return sessions.get(token);
    },
    listProducts() {
      return Array.from(productsById.values());
    },
    findProductById(id) {
      return productsById.get(id);
    },
    addProduct({ name, description, price, code, createdBy }) {
      if (productIdByCode.has(code)) return null;
      const product = {
        id: crypto.randomUUID(),
        name,
        description,
        price,
        code,
        createdBy,
        createdAt: new Date().toISOString(),
      };
      productsById.set(product.id, product);
      productIdByCode.set(code, product.id);
      return product;
    },
  };
}

module.exports = { createStore };
