# ubiquitous-octo-fishstick

Ecommerce service: customers register and sign in, signed-in users add products to the catalog, and anyone can browse it. All data is kept in memory and is lost when the service stops.

## Run

```bash
npm install
npm start          # listens on PORT (default 3000)
npm test
```

Or with Docker: `docker build -t shop . && docker run -p 3000:3000 shop`.

## API

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/health` | – | Liveness check |
| POST | `/api/auth/register` | – | Body `{email, password}`. 201 with the account, 409 if the email is taken, 400 if invalid (password ≥ 8 chars). Emails are case-insensitive. |
| POST | `/api/auth/login` | – | Body `{email, password}`. 200 `{token, user}`, 401 on bad credentials. |
| GET | `/api/products` | – | Full catalog |
| GET | `/api/products/:id` | – | One product, 404 if unknown |
| POST | `/api/products` | Bearer token | Body `{name, description, price, code}`. 201 with the product, 409 if the code is taken, 400 if invalid, 401 without sign-in. |

Send the token from sign-in as `Authorization: Bearer <token>`. Passwords are stored as scrypt hashes and never returned.
