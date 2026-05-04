# Food Rush API — endpoint tables (management components)

Base URL examples: `http://localhost:8080` · Android emulator → `http://10.0.2.2:8080`.

Many routes expect signed-in identity via header **`X-User-Id: <numeric user id>`** (Flutter / mobile clients).

---

## 1. Identity & authentication

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/status` | API status + stack info + management component list |
| POST | `/api/auth/signup` | Register (`name`, `email`, `password`, optional `role`, `mobile`, `address`) |
| POST | `/api/auth/signin` | Login (`email`, `password`); returns user JSON (no password hash) |

---

## 2. User management

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/users` | List all users |
| POST | `/api/users` | Create user (random password placeholder) |
| GET | `/api/users/:userId/orders` | Orders for user (`limit`, `offset`, `status` query optional) |
| GET | `/api/users/:id` | Get user by id |
| PUT | `/api/users/:id` | Update profile; **`X-User-Id`** self or admin; admin can change `role` |
| DELETE | `/api/users/:id` | Delete user |

---

## 3. Restaurant management

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/stores` | List stores (`ownerUserId` query optional) |
| GET | `/api/restaurants` | Alias of stores list (restaurant naming) |
| POST | `/api/stores` | Create store |
| POST | `/api/restaurants` | Alias of store create (restaurant naming) |
| GET | `/api/stores/:id/menu` | Menu items for store |
| GET | `/api/stores/:storeId/orders` | Orders for store |
| GET | `/api/stores/:id` | Store by id |
| GET | `/api/restaurants/:id` | Alias of store by id |
| PUT | `/api/stores/:id` | Update store |
| PUT | `/api/restaurants/:id` | Alias of store update |
| DELETE | `/api/stores/:id` | Delete store (+ menu rows + inventory) |
| DELETE | `/api/restaurants/:id` | Alias of store delete |
 
---

## 4. Menu management

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/menu_items` | List menu items (`storeId` query optional) |
| GET | `/api/menu_items/:id` | Get menu item by id |
| POST | `/api/menu_items` | Create menu item (+ inventory row) |
| GET | `/api/menu` | Alias of menu list endpoint |
| GET | `/api/menu/:id` | Alias of menu item by id |
| POST | `/api/menu` | Alias of menu item create |
| PUT | `/api/menu_items/:id` | Update menu item |
| PUT | `/api/menu/:id` | Alias of menu item update |
| DELETE | `/api/menu_items/:id` | Delete menu item (+ inventory) |
| DELETE | `/api/menu/:id` | Alias of menu item delete |
 
---

## 5. Inventory management

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/inventory` | List inventory rows (`storeId` filter optional) |
| POST | `/api/inventory` | Upsert by `menuItemId` |
| PUT | `/api/inventory/:id` | Set `quantity` |
| DELETE | `/api/inventory/:id` | Delete inventory row |

---

## 6. Order and cart management

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/carts/audit` | Cart headers + line counts — **admin only** (`X-User-Id` admin) |
| GET | `/api/carts/user/:userId` | Active cart for user (+ items) |
| POST | `/api/carts` | Create-or-get active cart (`userId`, optional `storeId`) |
| POST | `/api/carts/:cartId/checkout` | Mark cart CHECKED_OUT |
| DELETE | `/api/carts/:cartId` | Mark cart ABANDONED (keeps line snapshot) |
| POST | `/api/carts/:cartId/items` | Add line (`productId`, `name`, `qty`, `unitPrice`, optional `lineNote`) |
| PUT | `/api/carts/:cartId/items/:itemId` | Set line `qty` (0 deletes line) |
| DELETE | `/api/carts/:cartId/items/:itemId` | Remove line |
| POST | `/api/orders` | Create order (`items`, `storeId`, `currency`, `deliveryFee`, …; optional `cartId` cleanup) |
| GET | `/api/orders` | List (`userId`, `storeId`, `status`, `limit`, `offset`) |
| GET | `/api/orders/:id` | Order + lines |
| PUT | `/api/orders/:id` | Update `status` and/or replace `items` |
| DELETE | `/api/orders/:id` | Delete (blocked for some paid/active statuses) |

---

## 7. Payment management

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/refund-requests` | Customer refund request (**`X-User-Id`**) |
| GET | `/api/refund-requests` | List: admin all; customer `?userId=` must match header |
| PATCH | `/api/refund-requests/:id` | Admin update status/note |
| POST | `/api/payments/paypal/create` | Start PayPal Checkout (`orderId`) |
| POST | `/api/payments/paypal/capture` | Capture after approval (`orderId`) |
| POST | `/api/payments/cod/confirm` | COD confirm (`orderId`) |
| POST | `/api/payments/online-banking/confirm` | Bank demo (`orderId`, optional `reference`) |
| GET | `/api/payments/paypal/return` | Browser return (plain text) |
| GET | `/api/payments/paypal/cancel` | Browser cancel (plain text) |
| GET | `/api/payments` | List payments (filters: `orderId`, `method`, `status`) |
| GET | `/api/payments/:id` | Payment by id |
| POST | `/api/payments` | Create payment row |
| PUT | `/api/payments/:id` | Patch payment (`CAPTURED` syncs order + receipt) |
| DELETE | `/api/payments/:id` | Delete payment (+ linked receipts cleanup) |
| GET | `/api/receipts/:orderId` | Receipt payload for Flutter polling |

---

## 8. Admin and delivery management

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/deliveries` | List deliveries |
| POST | `/api/deliveries` | Create delivery (`orderId`, optional driver fields); unique per order |
| PUT | `/api/deliveries/:id` | Update status/driver/location (`OUT_FOR_DELIVERY` needs coords) |
| DELETE | `/api/deliveries/:id` | Delete delivery row |
| GET | `/api/drivers` | List drivers (`status`, `verified`, `limit`, `offset`) |
| POST | `/api/drivers` | Upsert driver profile |
| GET | `/api/drivers/metrics/leaderboard` | Leaderboard |
| GET | `/api/drivers/:driverId/metrics` | Per-driver metrics |
| GET | `/api/drivers/:id` | Driver detail |
| PUT | `/api/drivers/:id` | Update driver |
| DELETE | `/api/drivers/:id` | Strip driver role + profile |
| GET | `/api/driver-ratings` | List ratings (`driverId`, `orderId`, pagination) |
| POST | `/api/driver-ratings` | Create rating |
| PUT | `/api/driver-ratings/:id` | Update rating |
| POST | `/api/customer-feedback` | Submit rating/feedback (**`X-User-Id`**) |
| GET | `/api/customer-feedback/me` | Own entries (**`X-User-Id`**) |
| GET | `/api/customer-feedback` | All entries (**admin** + **`X-User-Id`**) |

---

### Quick counts

| # | Component | Route groups |
|---|-----------|----------------|
| 1 | Identity & authentication | `/api/auth` |
| 2 | User management | `/api/users` |
| 3 | Restaurant management | `/api/stores`, `/api/restaurants` |
| 4 | Menu management | `/api/menu_items`, `/api/menu` |
| 5 | Inventory management | `/api/inventory` |
| 6 | Order and cart management | `/api/orders`, `/api/carts` |
| 7 | Payment management | `/api/refund-requests`, `/api/payments`, `/api/receipts` |
| 8 | Admin and delivery management | `/api/deliveries`, `/api/drivers`, `/api/driver-ratings`, `/api/customer-feedback` |

For MongoDB indexes and collection names see `src/config/mongo.js`.
