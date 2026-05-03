# REST API endpoint tables

Each section is **one component** — same column layout everywhere: **Method | Endpoint | Description | Protected.**

**Protected** means the handler checks **`X-User-Id`** (numeric user id) and/or **admin role** (`401` / `403` if missing or wrong). **No** means the server does **not** enforce that header today (calls may still assume a trusted client; harden before public internet exposure).

Sign-in responses return a **sanitized user JSON** (password hash stripped). **This backend does not issue JWT**; the Flutter client sends **`X-User-Id`** after sign-in where noted.

---

## Authentication (`/api/auth`)

| Method | Endpoint | Description | Protected |
|--------|----------|-------------|-----------|
| POST | `/api/auth/signup` | Register a new user account (`name`, `email`, `password`, optional role/mobile/address) | No |
| POST | `/api/auth/signin` | Authenticate with email/password; returns user JSON (no JWT cookie in this API) | No |

*Comparable names in other APIs: `/api/auth/register` ≈ signup, `/api/auth/login` ≈ signin. There is no `/api/auth/me`, password-change, or `/api/auth/users` route.*

---

## Stores (`/api/stores`)

| Method | Endpoint | Description | Protected |
|--------|----------|-------------|-----------|
| GET | `/api/stores` | List stores (`ownerUserId` query optional) | No |
| POST | `/api/stores` | Create a store | No |
| GET | `/api/stores/:id/menu` | Menu items for that store | No |
| GET | `/api/stores/:storeId/orders` | Orders for that store (pagination/status query params) | No |
| GET | `/api/stores/:id` | Get store by id | No |
| PUT | `/api/stores/:id` | Update store | No |
| DELETE | `/api/stores/:id` | Delete store (cascades related catalog data server-side) | No |

---

## Orders & refund requests (`/api/orders`, `/api/refund-requests`)

| Method | Endpoint | Description | Protected |
|--------|----------|-------------|-----------|
| POST | `/api/orders` | Create order from line items (+ optional cart cleanup) | No |
| GET | `/api/orders` | List orders (filter by `userId`, `storeId`, `status`, pagination) | No |
| GET | `/api/orders/:id` | Order detail with line items | No |
| PUT | `/api/orders/:id` | Update status and/or replace line items | No |
| DELETE | `/api/orders/:id` | Delete order (blocked for certain active/paid statuses) | No |
| POST | `/api/refund-requests` | Customer opens a refund request for their order | Yes |
| GET | `/api/refund-requests` | List refunds (customers: own only; admins: all — filter helpers) | Yes |
| PATCH | `/api/refund-requests/:id` | Admin updates refund status / note | Yes |

---

## Payments & receipts (`/api/payments`, `/api/receipts`)

| Method | Endpoint | Description | Protected |
|--------|----------|-------------|-----------|
| POST | `/api/payments/paypal/create` | Start PayPal checkout for an order (`orderId`) | No |
| POST | `/api/payments/paypal/capture` | Capture PayPal payment after approval | No |
| POST | `/api/payments/cod/confirm` | Mark COD demo payment for order | No |
| POST | `/api/payments/online-banking/confirm` | Mark online-banking demo payment | No |
| GET | `/api/payments/paypal/return` | PayPal redirect return (plain text) | No |
| GET | `/api/payments/paypal/cancel` | PayPal redirect cancel (plain text) | No |
| GET | `/api/payments` | List payments (`orderId`, `method`, `status` filters) | No |
| GET | `/api/payments/:id` | Payment row by id | No |
| POST | `/api/payments` | Create payment record | No |
| PUT | `/api/payments/:id` | Update payment (capturing syncs receipt/order where applicable) | No |
| DELETE | `/api/payments/:id` | Delete payment (cleans linked receipts) | No |
| GET | `/api/receipts/:orderId` | Receipt payload by order id (polling from app) | No |

---

## Users (`/api/users`)

| Method | Endpoint | Description | Protected |
|--------|----------|-------------|-----------|
| GET | `/api/users` | List all users | No |
| POST | `/api/users` | Create user (staff-style; password is random internally) | No |
| GET | `/api/users/:userId/orders` | Orders belonging to user (pagination/status) | No |
| GET | `/api/users/:id` | Get user profile by id | No |
| PUT | `/api/users/:id` | Update profile (**self + `X-User-Id`**, or **admin**) | Yes |
| DELETE | `/api/users/:id` | Delete user document | No |

---

## Deliveries (`/api/deliveries`)

| Method | Endpoint | Description | Protected |
|--------|----------|-------------|-----------|
| GET | `/api/deliveries` | List delivery jobs | No |
| POST | `/api/deliveries` | Create delivery for order (one delivery per order) | No |
| PUT | `/api/deliveries/:id` | Update status/driver/location/time fields | No |
| DELETE | `/api/deliveries/:id` | Remove delivery row | No |

---

## Carts (`/api/carts`)

| Method | Endpoint | Description | Protected |
|--------|----------|-------------|-----------|
| GET | `/api/carts/audit` | Recent carts with line counts (**admin role + `X-User-Id`**) | Yes |
| GET | `/api/carts/user/:userId` | Active cart and items for a user id | No |
| POST | `/api/carts` | Create or return existing ACTIVE cart (`userId`, optional `storeId`) | No |
| POST | `/api/carts/:cartId/checkout` | Mark cart CHECKED_OUT | No |
| DELETE | `/api/carts/:cartId` | Mark cart ABANDONED | No |
| POST | `/api/carts/:cartId/items` | Add/update line quantity for a product line | No |
| PUT | `/api/carts/:cartId/items/:itemId` | Set line quantity (zero removes line) | No |
| DELETE | `/api/carts/:cartId/items/:itemId` | Delete one cart line | No |
