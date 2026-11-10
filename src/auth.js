'use strict';

// Requires "Authorization: Bearer <token>" from a successful sign-in.
function requireAuth(store) {
  return (req, res, next) => {
    const header = req.get('authorization') || '';
    const match = /^Bearer\s+(\S+)$/i.exec(header);
    const userId = match ? store.userIdForToken(match[1]) : undefined;
    const user = userId ? store.findUserById(userId) : undefined;
    if (!user) {
      return res.status(401).json({ error: 'Sign in required' });
    }
    req.user = user;
    return next();
  };
}

module.exports = { requireAuth };
