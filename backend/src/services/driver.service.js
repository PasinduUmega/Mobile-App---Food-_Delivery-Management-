import { coll } from '../repositories/mongo.repository.js';
import { asInt } from '../utils/parsers.js';

export function normalizeDriverStatus(raw) {
  const s = String(raw ?? 'ACTIVE').trim().toUpperCase();
  if (['ACTIVE', 'INACTIVE', 'ON_DELIVERY', 'PENDING_VERIFICATION'].includes(s)) {
    return s;
  }
  return 'ACTIVE';
}

export async function computeDriverRuntimeStatus(profileRow) {
  const base = normalizeDriverStatus(profileRow?.status);
  if (base === 'INACTIVE' || base === 'PENDING_VERIFICATION') return base;
  const phone = String(profileRow?.phone ?? '').trim();
  const name = String(profileRow?.name ?? '').trim();
  const p = phone || '__none__';
  const n = name || '__none__';
  const doc = await coll('deliveries').findOne({
    status: { $in: ['PENDING', 'PICKED_UP', 'OUT_FOR_DELIVERY'] },
    $or: [{ driver_phone: p }, { driver_name: n }],
  }, { projection: { id: 1 } });
  return doc ? 'ON_DELIVERY' : 'ACTIVE';
}

export async function getDriverRatingAgg(driverUid) {
  const [rec] = await coll('driverRatings').aggregate([
    { $match: { driver_id: driverUid } },
    { $group: { _id: null, cnt: { $sum: 1 }, avg_rating: { $avg: '$rating' } } },
  ]).toArray();
  return rec ?? { cnt: 0, avg_rating: null };
}

export async function getDriverByUserId(userId) {
  const uid = asInt(userId);
  const udoc = await coll('users').findOne({ id: uid, role: 'DELIVERY_DRIVER' });
  if (!udoc) return null;
  const dp = await coll('driverProfiles').findOne({ user_id: uid });
  const ratingAgg = await getDriverRatingAgg(uid);

  const row = {
    id: udoc.id,
    user_id: udoc.id,
    name: udoc.name,
    phone: udoc.mobile,
    email: udoc.email,
    vehicle_type: dp?.vehicle_type,
    vehicle_number: dp?.vehicle_number,
    license_number: dp?.license_number,
    status: dp?.status ?? 'ACTIVE',
    verified: dp?.verified ? 1 : 0,
    verified_at: dp?.verified_at,
    created_at: udoc.created_at,
    updated_at: udoc.updated_at,
  };

  const runtimeStatus = await computeDriverRuntimeStatus(row);
  return {
    ...row,
    status: runtimeStatus,
    ratings_count: Number(ratingAgg?.cnt ?? 0),
    ratings_average: ratingAgg?.avg_rating != null ? Number(ratingAgg.avg_rating) : null,
    verified: row.verified ? 1 : 0,
  };
}
