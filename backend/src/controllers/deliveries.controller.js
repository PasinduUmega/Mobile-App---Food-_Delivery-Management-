import { COLL, isMongoDuplicate, nextSeq } from '../config/mongo.js';
import { coll } from '../repositories/mongo.repository.js';
import { isDriverBusy } from '../services/orderFulfillment.service.js';
import { asFloat, asInt } from '../utils/parsers.js';

export async function listDeliveries(_req, res) {
  try {
    const rows = await coll('deliveries').find().sort({ id: -1 }).toArray();
    res.json({ items: rows });
  } catch (_e) {
    res.status(500).json({ error: 'failed to fetch deliveries' });
  }
}

export async function createDelivery(req, res) {
  const { orderId, driverName, driverPhone } = req.body || {};
  if (!orderId) return res.status(400).json({ error: 'orderId required' });
  try {
    const phone = String(driverPhone ?? '').trim();
    if (phone) {
      const busy = await isDriverBusy({ driverPhone: phone });
      if (busy) {
        return res.status(409).json({ error: 'driver is busy with another active delivery' });
      }
    }
    const nid = await nextSeq(COLL.deliveries);
    const now = new Date();
    await coll('deliveries').insertOne({
      id: nid,
      order_id: asInt(orderId),
      driver_name: driverName || null,
      driver_phone: phone || null,
      status: 'PENDING',
      created_at: now,
      updated_at: now,
    });
    const created = await coll('deliveries').findOne({ id: nid });
    res.status(201).json(created);
  } catch (e) {
    if (isMongoDuplicate(e)) return res.status(409).json({ error: 'delivery for this order already exists' });
    res.status(500).json({ error: 'failed to create delivery' });
  }
}

export async function updateDelivery(req, res) {
  const id = asInt(req.params.id);
  const { status, driverName, driverPhone, pickupTime, deliveryTime, currentLatitude, currentLongitude } =
    req.body || {};
  if (!id) return res.status(400).json({ error: 'id required' });
  try {
    const deliveryRow = await coll('deliveries').findOne({ id });
    if (!deliveryRow) return res.status(404).json({ error: 'delivery not found' });
    const orderId = deliveryRow.order_id;

    const nextStatus = status ? String(status).trim().toUpperCase() : null;
    const phone = driverPhone != null ? String(driverPhone).trim() : null;
    if (phone) {
      const busy = await isDriverBusy({
        driverPhone: phone,
        excludeDeliveryId: id,
      });
      if (busy) {
        return res.status(409).json({ error: 'driver is busy with another active delivery' });
      }
    }

    if (nextStatus === 'OUT_FOR_DELIVERY') {
      const hasLat = currentLatitude != null && asFloat(currentLatitude) != null;
      const hasLng = currentLongitude != null && asFloat(currentLongitude) != null;
      if (!hasLat || !hasLng) {
        return res.status(400).json({
          error: 'currentLatitude and currentLongitude are required for OUT_FOR_DELIVERY',
        });
      }
    }

    const lat = currentLatitude != null ? asFloat(currentLatitude) : null;
    const lng = currentLongitude != null ? asFloat(currentLongitude) : null;
    const effectivePickupTime =
      nextStatus === 'PICKED_UP' && !pickupTime ? new Date() : pickupTime || null;
    const effectiveDeliveryTime =
      nextStatus === 'DELIVERED' && !deliveryTime ? new Date() : deliveryTime || null;

    const setDel = {
      status: nextStatus != null ? nextStatus : deliveryRow.status,
      driver_name: driverName != null ? driverName || null : deliveryRow.driver_name,
      driver_phone: phone != null ? phone || null : deliveryRow.driver_phone,
      pickup_time: effectivePickupTime != null ? effectivePickupTime : deliveryRow.pickup_time,
      delivery_time: effectiveDeliveryTime != null ? effectiveDeliveryTime : deliveryRow.delivery_time,
      current_latitude: lat != null ? lat : deliveryRow.current_latitude,
      current_longitude: lng != null ? lng : deliveryRow.current_longitude,
      updated_at: new Date(),
    };

    await coll('deliveries').updateOne({ id }, { $set: setDel });

    if (nextStatus) {
      const s = nextStatus;
      if (s === 'DELIVERED') {
        await coll('orders').updateOne(
          { id: orderId, status: { $nin: ['CANCELLED', 'FAILED'] } },
          { $set: { status: 'COMPLETED', updated_at: new Date() } },
        );
      } else if (s === 'PICKED_UP' || s === 'OUT_FOR_DELIVERY') {
        await coll('orders').updateOne(
          { id: orderId, status: { $nin: ['COMPLETED', 'CANCELLED', 'FAILED'] } },
          { $set: { status: 'READY', updated_at: new Date() } },
        );
      }
    }

    res.json({ ok: true });
  } catch (_e) {
    res.status(500).json({ error: 'failed to update delivery' });
  }
}

export async function deleteDelivery(req, res) {
  const id = asInt(req.params.id);
  if (!id) return res.status(400).json({ error: 'invalid id' });
  try {
    const result = await coll('deliveries').deleteOne({ id });
    res.json({ deleted: result.deletedCount === 1 });
  } catch (_e) {
    res.status(500).json({ error: 'failed to delete delivery' });
  }
}
