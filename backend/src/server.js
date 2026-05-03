import 'dotenv/config';
import { connectMongo, getDb, COLL } from './config/mongo.js';
import { createApp } from './app.js';
import { seedDefaultAdmin } from './bootstrap/adminSeed.js';

async function ensureSchema() {
  /* Collections + indexes created in ./config/mongo.js at connectMongo() */
}

async function main() {
  try {
    await connectMongo();
    await ensureSchema();
    await seedDefaultAdmin();
    if ((process.env.SEED_DEMO_DATA || '').toLowerCase() === 'true') {
      const ocount = await getDb().collection(COLL.orders).countDocuments();
      if (ocount === 0) {
        console.warn(
          'MongoDB: SEED_DEMO_DATA is set but automatic SQL-style seeding is disabled. Create stores, menu, and orders via the app or API.',
        );
      }
    }
  } catch (e) {
    console.error('Failed to connect MongoDB', e);
    process.exit(1);
  }

  const app = createApp();
  const port = Number(process.env.PORT || 8080);
  app.listen(port, '0.0.0.0', () => {
    console.log(`API listening on ${port}`);
  });
}

main();
