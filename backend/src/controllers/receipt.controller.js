import { coll } from '../repositories/mongo.repository.js';
import { asInt } from '../utils/parsers.js';

export async function getReceipt(req, res) {
  const orderId = asInt(req.params.orderId);
  const order = await coll('orders').findOne(
    { id: orderId },
    { projection: { id: 1, status: 1, total: 1, currency: 1 } },
  );
  if (!order) return res.status(404).json({ error: 'order not found' });

  const receipt = await coll('receipts').findOne({ order_id: orderId });

  let paymentJoined = null;
  if (receipt) {
    const p = await coll('payments').findOne({ id: receipt.payment_id });
    if (p) {
      paymentJoined = {
        receipt_no: receipt.receipt_no,
        issued_at: receipt.issued_at,
        paid_amount: receipt.paid_amount,
        currency: receipt.currency,
        method: p.method,
        payment_status: p.status,
      };
    }
  }

  res.json({
    orderId: order.id,
    orderStatus: order.status,
    total: Number(order.total),
    currency: order.currency,
    receipt: paymentJoined
      ? {
          receiptNo: paymentJoined.receipt_no,
          issuedAt: paymentJoined.issued_at,
          paidAmount: Number(paymentJoined.paid_amount),
          currency: paymentJoined.currency,
          paymentMethod: paymentJoined.method,
          paymentStatus: paymentJoined.payment_status,
        }
      : null,
  });
}
