# food_rush backend (User CRUD)

This backend provides REST APIs for user registration CRUD stored in MySQL database `food_rush`.

## 1) MySQL setup

Run:
`sql/schema.sql`

It creates:
- database `food_rush`
- table `users`

## 2) Configure environment

Copy `.env.example` to `.env` and set `DB_PASSWORD`.

## 3) Install and run

From `backend/`:
`npm install`
`npm start`

Server:
- `GET  /api/health`
- `GET  /api/users`
- `POST /api/users`
- `GET  /api/users/:id`
- `PUT  /api/users/:id`
- `DELETE /api/users/:id`

## API payloads (example)

Create:
```
{
  "name": "John",
  "email": "john@example.com",
  "mobile": "0771234567",
  "address": "Somewhere",
  "password": "secret"
}
```

Update (password optional):
```
{
  "name": "New Name",
  "address": "New Address",
  "password": "new secret"
}
```

