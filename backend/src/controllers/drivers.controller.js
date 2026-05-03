import { COLL, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';
import {
  computeDriverRuntimeStatus,
  getDriverByUserId,
  getDriverRatingAgg,
  normalizeDriverStatus,
} from '../services/driver.service.js';
import { asInt } from '../utils/parsers.js';

export async function listDrivers(req, res) {
  const status = req.query.status ? String(req.query.status).toUpperCase() : null;
  const verified = req.query.verified != null ? String(req.query.verified) : null;
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 500) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;

  const drivers = await coll('users').find({ role: 'DELIVERY_DRIVER' }).sort({ id: -1 }).skip(offset).limit(limit).toArray();
  const profiles = await coll('driverProfiles').find({
    user_id: { $in: drivers.map((d) => d.id) },
  }).toArray();
  const pmap = Object.fromEntries(profiles.map((p) => [p.user_id, p]));

  const items = [];
  for (const udoc of drivers) {
    const dp = pmap[udoc.id];
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
      verified: dp?.verified,
      verified_at: dp?.verified_at,
      created_at: udoc.created_at,
      updated_at: udoc.updated_at,
    };
    const runtimeStatus = await computeDriverRuntimeStatus(row);
    if (status && runtimeStatus !== status) continue;
    if (verified != null) {
      const shouldBeVerified = verified === '1' || verified.toLowerCase() === 'true';
      const isVerified = Boolean(row.verified);
      if (shouldBeVerified !== isVerified) continue;
    }
    const agg = await getDriverRatingAgg(udoc.id);
    items.push({
      ...row,
      status: runtimeStatus,
      ratings_count: Number(agg?.cnt ?? 0),
      ratings_average: agg?.avg_rating != null ? Number(agg.avg_rating) : null,
      verified: row.verified ? 1 : 0,
    });
  }
  res.json({ items });
}

export async function getDriver(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const driver = await getDriverByUserId(id);
  if (!driver) return res.status(404).json({ error: 'driver not found' });
  res.json(driver);
}

export async function createDriver(req, res) {
  const userId = asInt(req.body?.userId);
  const name = String(req.body?.name ?? '').trim();
  const phone = req.body?.phone != null ? String(req.body.phone).trim() : null;
  const email = req.body?.email != null ? String(req.body.email).trim().toLowerCase() : null;
  const vehicleType = req.body?.vehicleType != null ? String(req.body.vehicleType).trim() : null;
  const vehicleNumber = req.body?.vehicleNumber != null ? String(req.body.vehicleNumber).trim() : null;
  const licenseNumber = req.body?.licenseNumber != null ? String(req.body.licenseNumber).trim() : null;
  if (!userId || !name) return res.status(400).json({ error: 'userId and name required' });

  try {
    const udoc = await coll('users').findOne({ id: userId });
    if (!udoc) return res.status(404).json({ error: 'user not found' });

    const now = new Date();
    const uset = { name, role: 'DELIVERY_DRIVER', updated_at: now };
    if (email != null) uset.email = email;
    if (phone !== null) uset.mobile = phone;
    await coll('users').updateOne({ id: userId }, { $set: uset });

    await coll('driverProfiles').updateOne(
      { user_id: userId },
      {
        $set: {
          user_id: userId,
          vehicle_type: vehicleType ?? null,
          vehicle_number: vehicleNumber ?? null,
          license_number: licenseNumber ?? null,
          status: 'ACTIVE',
          verified: false,
          updated_at: now,
        },
        $setOnInsert: { created_at: now },
      },
      { upsert: true },
    );

    const driver = await getDriverByUserId(userId);
    res.status(201).json(driver);
  } catch (_e) {
    res.status(500).json({ error: 'failed to create driver profile' });
  }
}

export async function updateDriver(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const name = req.body?.name != null ? String(req.body.name).trim() : null;
  const phone = req.body?.phone != null ? String(req.body.phone).trim() : null;
  const email = req.body?.email != null ? String(req.body.email).trim().toLowerCase() : null;
  const vehicleType = req.body?.vehicleType != null ? String(req.body.vehicleType).trim() : null;
  const vehicleNumber = req.body?.vehicleNumber != null ? String(req.body.vehicleNumber).trim() : null;
  const licenseNumber = req.body?.licenseNumber != null ? String(req.body.licenseNumber).trim() : null;
  const dStatus = req.body?.status != null ? normalizeDriverStatus(req.body.status) : null;
  const verifiedExplicit = req.body?.verified !== undefined ? Boolean(req.body.verified) : null;

  try {
    const udoc = await coll('users').findOne({ id });
    if (!udoc) {
      return res.status(404).json({ error: 'driver user not found' });
    }
    const now = new Date();
    const uset = { role: 'DELIVERY_DRIVER', updated_at: now };
    if (name != null) uset.name = name;
    if (email != null) uset.email = email;
    if (phone != null) uset.mobile = phone;
    await coll('users').updateOne({ id }, { $set: uset });

    const cur = await coll('driverProfiles').findOne({ user_id: id });
    const nextVerified =
      verifiedExplicit === null ? Boolean(cur?.verified) : verifiedExplicit;

    await coll('driverProfiles').updateOne(
      { user_id: id },
      {
        $set: {
          vehicle_type: vehicleType !== null ? vehicleType : cur?.vehicle_type ?? null,
          vehicle_number: vehicleNumber !== null ? vehicleNumber : cur?.vehicle_number ?? null,
          license_number: licenseNumber !== null ? licenseNumber : cur?.license_number ?? null,
          status: dStatus ?? cur?.status ?? 'ACTIVE',
          verified: nextVerified,
          verified_at: verifiedExplicit !== null ? (nextVerified ? now : null) : cur?.verified_at,
          updated_at: now,
        },
        $setOnInsert: { user_id: id, created_at: now },
      },
      { upsert: true },
    );

    const driver = await getDriverByUserId(id);
    res.json(driver);
  } catch (_e) {
    res.status(500).json({ error: 'failed to update driver profile' });
  }
}

export async function deleteDriver(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const r = await coll('users').updateOne(
      { id },
      { $set: { role: 'CUSTOMER', updated_at: new Date() } },
    );
    await coll('driverProfiles').deleteMany({ user_id: id });
    res.json({ deleted: r.matchedCount === 1 });
  } catch (_e) {
    res.status(500).json({ error: 'failed to delete driver profile' });
  }
}

export async function driverMetrics(req, res) {
  const driverId = asInt(req.params.driverId);
  if (!driverId) return res.status(400).json({ error: 'invalid driverId' });

  const driver = await coll('users').findOne(
    { id: driverId, role: 'DELIVERY_DRIVER' },
    { projection: { id: 1, name: 1, mobile: 1 } },
  );
  if (!driver) return res.status(404).json({ error: 'driver not found' });

  const uPhone = driver.mobile ?? '';
  const delRows = await coll('deliveries').find({
    $or: [{ driver_name: driver.name }, { driver_phone: uPhone }],
  }).project({ status: 1, delivery_time: 1 }).toArray();

  const totalDeliveries = delRows.length;
  const completedDeliveries = delRows.filter((d) => String(d.status).toUpperCase() === 'DELIVERED').length;

  const [ratingAgg] = await coll('driverRatings').aggregate([
    { $match: { driver_id: driverId } },
    {
      $group: {
        _id: null,
        rating_count: { $sum: 1 },
        average_rating: { $avg: '$rating' },
      },
    },
  ]).toArray();

  const distRows = await coll('driverRatings').aggregate([
    { $match: { driver_id: driverId } },
    { $group: { _id: '$rating', c: { $sum: 1 } } },
  ]).toArray();

  const ratingDistribution = [0, 0, 0, 0, 0];
  for (const rRow of distRows) {
    const idx = Number(rRow._id) - 1;
    if (idx >= 0 && idx < 5) ratingDistribution[idx] = Number(rRow.c);
  }

  const lastDelivery = await coll('deliveries').findOne(
    {
      delivery_time: { $ne: null },
      $or: [{ driver_name: driver.name }, { driver_phone: uPhone }],
    },
    { sort: { delivery_time: -1 }, projection: { delivery_time: 1 } },
  );

  res.json({
    driver_id: driverId,
    driver_name: driver.name,
    total_deliveries: totalDeliveries,
    completed_deliveries: completedDeliveries,
    average_rating: ratingAgg?.average_rating != null ? Number(ratingAgg.average_rating) : 0,
    rating_count: Number(ratingAgg?.rating_count ?? 0),
    average_delivery_time: null,
    last_delivery: lastDelivery?.delivery_time ?? null,
    rating_distribution: ratingDistribution,
  });
}

export async function driverLeaderboard(req, res) {
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 20, 1), 200) : 20;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;
  const drivers = await coll('users').find({ role: 'DELIVERY_DRIVER' }).sort({ id: -1 }).skip(offset).limit(limit).project({ id: 1, name: 1, mobile: 1 }).toArray();
  const items = [];
  for (const d of drivers) {
    const [ratingAggLocal] = await coll('driverRatings').aggregate([
      { $match: { driver_id: d.id } },
      {
        $group: {
          _id: null,
          rating_count: { $sum: 1 },
          average_rating: { $avg: '$rating' },
        },
      },
    ]).toArray();
    const phone = d.mobile ?? '';
    const delRows = await coll('deliveries').find({
      $or: [{ driver_name: d.name }, { driver_phone: phone }],
    }).project({ status: 1 }).toArray();
    items.push({
      driver_id: d.id,
      driver_name: d.name,
      total_deliveries: delRows.length,
      completed_deliveries: delRows.filter((x) => String(x.status).toUpperCase() === 'DELIVERED').length,
      average_rating: ratingAggLocal?.average_rating != null ? Number(ratingAggLocal.average_rating) : 0,
      rating_count: Number(ratingAggLocal?.rating_count ?? 0),
      average_delivery_time: null,
      last_delivery: null,
      rating_distribution: [0, 0, 0, 0, 0],
    });
  }
  items.sort((a, b) => b.average_rating - a.average_rating);
  res.json({ items });
}

export async function listDriverRatings(req, res) {
  const driverId = req.query.driverId ? asInt(req.query.driverId) : null;
  const orderId = req.query.orderId ? asInt(req.query.orderId) : null;
  const limit = req.query.limit ? Math.min(Math.max(asInt(req.query.limit) ?? 50, 1), 300) : 50;
  const offset = req.query.offset ? Math.max(asInt(req.query.offset) ?? 0, 0) : 0;
  const filter = {};
  if (driverId) filter.driver_id = driverId;
  if (orderId) filter.order_id = orderId;
  const rows = await coll('driverRatings').find(filter).sort({ id: -1 }).skip(offset).limit(limit).toArray();
  const cids = [...new Set(rows.map((r) => r.customer_id).filter(Boolean))];
  const cusers = cids.length
    ? await coll('users').find({ id: { $in: cids } }).project({ id: 1, name: 1 }).toArray()
    : [];
  const cmap = Object.fromEntries(cusers.map((u) => [u.id, u.name]));
  const out = rows.map((r) => ({
    ...r,
    customer_name: r.is_anonymous ? null : (cmap[r.customer_id] ?? null),
  }));
  res.json({ items: out });
}

export async function createDriverRating(req, res) {
  const driverId = asInt(req.body?.driverId);
  const orderId = asInt(req.body?.orderId);
  const customerId = req.body?.customerId ? asInt(req.body.customerId) : null;
  const rating = asInt(req.body?.rating);
  const feedback = req.body?.feedback != null ? String(req.body.feedback).trim() : null;
  const category = req.body?.category != null ? String(req.body.category).trim() : null;
  const isAnonymous = req.body?.isAnonymous ? 1 : 0;

  if (!driverId || !orderId || !rating || rating < 1 || rating > 5) {
    return res.status(400).json({ error: 'driverId, orderId and rating(1-5) required' });
  }

  const rid = await nextSeq(COLL.driverRatings);
  const now = new Date();
  await coll('driverRatings').insertOne({
    id: rid,
    driver_id: driverId,
    order_id: orderId,
    customer_id: customerId,
    rating,
    feedback: feedback || null,
    category: category || null,
    is_anonymous: isAnonymous,
    created_at: now,
    updated_at: now,
  });
  const created = await coll('driverRatings').findOne({ id: rid });
  res.status(201).json(created);
}

export async function updateDriverRating(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  const rating = req.body?.rating != null ? asInt(req.body.rating) : null;
  const feedback = req.body?.feedback != null ? String(req.body.feedback).trim() : null;
  const category = req.body?.category != null ? String(req.body.category).trim() : null;
  if (rating != null && (rating < 1 || rating > 5)) {
    return res.status(400).json({ error: 'rating must be between 1 and 5' });
  }
  const existing = await coll('driverRatings').findOne({ id });
  if (!existing) return res.status(404).json({ error: 'rating not found' });

  await coll('driverRatings').updateOne(
    { id },
    {
      $set: {
        ...(rating != null ? { rating } : {}),
        ...(feedback != null ? { feedback } : {}),
        ...(category != null ? { category } : {}),
        updated_at: new Date(),
      },
    },
  );
  const updated = await coll('driverRatings').findOne({ id });
  res.json(updated);
}
