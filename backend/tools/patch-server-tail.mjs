/**
 * One-off splice: replaces MySQL ensureSchema/bootstrap tail with MongoDB startup.
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverPath = path.join(__dirname, '..', 'src', 'server.js');

const newTail = `async function ensureSchema() {
  /* Collections + indexes created in ./config/mongo.js at connectMongo() */
}

async function ensureDefaultAdminAccount() {
  const defaultAdminEmail = 'admin@gmail.com';
  const defaultAdminPassword = '123456';
  const existing = await getDb().collection(COLL.users).findOne({ email: defaultAdminEmail });
  if (existing) return;

  const bcrypt = await import('bcryptjs');
  const passwordHash = await bcrypt.hash(defaultAdminPassword, 10);
  const uid = await nextSeq(COLL.users);
  const now = new Date();
  await getDb().collection(COLL.users).insertOne({
    id: uid,
    name: 'System Admin',
    email: defaultAdminEmail,
    password_hash: passwordHash,
    role: 'ADMIN',
    created_at: now,
    updated_at: now,
  });
  console.log('✓ Created default admin account: admin@gmail.com');
}

async function main() {
  try {
    await connectMongo();
    await ensureSchema();
    await ensureDefaultAdminAccount();

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

  const port = Number(process.env.PORT || 8080);
  app.listen(port, '0.0.0.0', () => {
    console.log(\`API listening on \${port}\`);
  });
}

main();
`;

let s = fs.readFileSync(serverPath, 'utf8');
const start = s.indexOf('async function ensureSchema()');
if (start < 0) throw new Error('ensureSchema anchor not found');
s = s.slice(0, start) + newTail;
fs.writeFileSync(serverPath, s);
console.log('Patched server.js tail (MongoDB bootstrap)');
