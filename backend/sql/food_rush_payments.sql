-- MySQL schema additions for food_rush (orders + payments + receipts)
-- Apply: mysql -u root -p food_rush < backend/sql/food_rush_payments.sql

-- Orders represent a checkout attempt; payments represent method + provider state.
CREATE TABLE IF NOT EXISTS orders (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NULL,
  store_id BIGINT UNSIGNED NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  subtotal DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  delivery_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  status ENUM('PENDING_PAYMENT','PAID','PREPARING','READY','COMPLETED','CANCELLED','FAILED') NOT NULL DEFAULT 'PENDING_PAYMENT',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_orders_user_id (user_id),
  KEY idx_orders_store_id (store_id),
  KEY idx_orders_status (status),
  KEY idx_orders_created_at (created_at)
);

CREATE TABLE IF NOT EXISTS order_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NULL,
  name VARCHAR(255) NOT NULL,
  qty INT UNSIGNED NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  line_total DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_order_items_order_id (order_id),
  CONSTRAINT fk_order_items_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  method ENUM('PAYPAL','CASH_ON_DELIVERY','ONLINE_BANKING') NOT NULL,
  status ENUM('CREATED','APPROVAL_PENDING','AUTHORIZED','CAPTURED','FAILED','CANCELLED') NOT NULL DEFAULT 'CREATED',
  provider VARCHAR(32) NULL,
  provider_order_id VARCHAR(128) NULL,
  provider_capture_id VARCHAR(128) NULL,
  approval_url TEXT NULL,
  amount DECIMAL(10,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payments_provider_order_id (provider_order_id),
  KEY idx_payments_order_id (order_id),
  KEY idx_payments_status (status),
  CONSTRAINT fk_payments_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS receipts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  order_id BIGINT UNSIGNED NOT NULL,
  payment_id BIGINT UNSIGNED NOT NULL,
  receipt_no VARCHAR(32) NOT NULL,
  issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  paid_amount DECIMAL(10,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'USD',
  raw_provider_response JSON NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_receipts_order_id (order_id),
  UNIQUE KEY uq_receipts_receipt_no (receipt_no),
  KEY idx_receipts_issued_at (issued_at),
  CONSTRAINT fk_receipts_order
    FOREIGN KEY (order_id) REFERENCES orders(id)
    ON DELETE CASCADE,
  CONSTRAINT fk_receipts_payment
    FOREIGN KEY (payment_id) REFERENCES payments(id)
    ON DELETE RESTRICT
);

-- Persistent shopping carts
CREATE TABLE IF NOT EXISTS carts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  store_id BIGINT UNSIGNED NULL,
  status ENUM('ACTIVE','CHECKED_OUT','ABANDONED') NOT NULL DEFAULT 'ACTIVE',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  checked_out_at TIMESTAMP NULL,
  PRIMARY KEY (id),
  KEY idx_carts_user_id (user_id),
  KEY idx_carts_status (status),
  KEY idx_carts_created_at (created_at)
);

-- Items in shopping carts
CREATE TABLE IF NOT EXISTS cart_items (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  cart_id BIGINT UNSIGNED NOT NULL,
  product_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  qty INT UNSIGNED NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_cart_items_product (cart_id, product_id),
  KEY idx_cart_items_cart_id (cart_id),
  CONSTRAINT fk_cart_items_cart
    FOREIGN KEY (cart_id) REFERENCES carts(id)
    ON DELETE CASCADE
);

-- Link orders to their source carts (optional for history tracking)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cart_id BIGINT UNSIGNED NULL;
ALTER TABLE orders ADD KEY IF NOT EXISTS idx_orders_cart_id (cart_id);
ALTER TABLE orders ADD CONSTRAINT IF NOT EXISTS fk_orders_cart
  FOREIGN KEY (cart_id) REFERENCES carts(id)
  ON DELETE SET NULL;

