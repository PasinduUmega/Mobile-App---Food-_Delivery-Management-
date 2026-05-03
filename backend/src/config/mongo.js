import { MongoClient } from 'mongodb';

const uri =
  process.env.MONGODB_URI?.trim() || 'mongodb://127.0.0.1:27017';
const dbName = process.env.MONGODB_DB?.trim() || 'food_rush';

let client;
let database;

/** Collection names aligned with legacy SQL tables (numeric `id` field on docs). */
export const COLL = {
  users: 'users',
  stores: 'stores',
  menuItems: 'menu_items',
  inventory: 'inventory',
  carts: 'carts',
  cartItems: 'cart_items',
  orders: 'orders',
  orderItems: 'order_items',
  payments: 'payments',
  receipts: 'receipts',
  deliveries: 'deliveries',
  driverProfiles: 'driver_profiles',
  driverRatings: 'driver_ratings',
  customerFeedback: 'customer_feedback',
  refundRequests: 'refund_requests',
  counters: 'counters',
};

export async function connectMongo() {
  client = new MongoClient(uri);
  await client.connect();
  database = client.db(dbName);
  await ensureIndexes(database);
  return database;
}

export function getDb() {
  if (!database) {
    throw new Error('MongoDB not connected yet (call connectMongo first)');
  }
  return database;
}

export async function closeMongo() {
  if (client) await client.close();
  client = null;
  database = null;
}

/**
 * Global monotonic integer id per logical entity (replaces AUTO_INCREMENT).
 * counter key convention: `${COLL.orders}` → matches collection name string.
 */
export async function nextSeq(counterKey) {
  const coll = getDb().collection(COLL.counters);
  await coll.updateOne(
    { _id: counterKey },
    {
      $inc: { seq: 1 },
      $setOnInsert: { created_at: new Date() },
    },
    { upsert: true },
  );
  const doc = await coll.findOne({ _id: counterKey });
  return doc.seq;
}

export function isMongoDuplicate(error) {
  return error?.code === 11000 || error?.codeName === 'DuplicateKey';
}

async function ensureIndexes(db) {
  async function uniq(collection, specs) {
    const c = db.collection(collection);
    for (const s of specs) {
      await c.createIndex(s.key, s.options ?? { unique: true });
    }
  }

  await uniq(COLL.users, [
    { key: { id: 1 }, options: { unique: true } },
    { key: { email: 1 }, options: { unique: true } },
  ]);
  await uniq(COLL.stores, [
    { key: { id: 1 }, options: { unique: true } },
    { key: { name: 1 }, options: { unique: true } },
  ]);
  await db.collection(COLL.menuItems).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.menuItems).createIndex({ store_id: 1 });
  await db.collection(COLL.inventory).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.inventory).createIndex({ menu_item_id: 1 }, { unique: true });
  await db.collection(COLL.carts).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.cartItems).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.cartItems).createIndex({ cart_id: 1 });
  await db.collection(COLL.cartItems).createIndex({ cart_id: 1, product_id: 1 }, { unique: true });
  await db.collection(COLL.orders).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.orders).createIndex({ user_id: 1 });
  await db.collection(COLL.orders).createIndex({ store_id: 1 });
  await db.collection(COLL.orders).createIndex({ status: 1 });
  await db.collection(COLL.orderItems).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.orderItems).createIndex({ order_id: 1 });
  await db.collection(COLL.payments).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.payments).createIndex({ order_id: 1 });
  await db.collection(COLL.payments).createIndex(
    { provider_order_id: 1 },
    { unique: true, sparse: true },
  );
  await db.collection(COLL.receipts).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.receipts).createIndex({ order_id: 1 }, { unique: true });
  await db.collection(COLL.receipts).createIndex({ receipt_no: 1 }, { unique: true });
  await db.collection(COLL.deliveries).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.deliveries).createIndex({ order_id: 1 }, { unique: true });
  await db.collection(COLL.deliveries).createIndex({ driver_phone: 1 });
  await db.collection(COLL.driverProfiles).createIndex({ user_id: 1 }, { unique: true });
  await db.collection(COLL.driverRatings).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.driverRatings).createIndex({ driver_id: 1 });
  await db.collection(COLL.customerFeedback).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.customerFeedback).createIndex({ user_id: 1 });
  await db.collection(COLL.refundRequests).createIndex({ id: 1 }, { unique: true });
  await db.collection(COLL.refundRequests).createIndex({ order_id: 1 });
}
