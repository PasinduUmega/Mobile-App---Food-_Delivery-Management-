import { Router } from 'express';
import * as pc from '../controllers/payments.controller.js';

export default function createPaymentsRouter(paypalClient) {
  const router = Router();
  router.post('/paypal/create', pc.paypalCreate(paypalClient));
  router.post('/paypal/capture', pc.paypalCapture(paypalClient));
  router.post('/cod/confirm', pc.confirmCod);
  router.post('/online-banking/confirm', pc.confirmOnlineBanking);
  router.get('/paypal/return', pc.paypalReturn);
  router.get('/paypal/cancel', pc.paypalCancel);
  router.get('/', pc.listPayments);
  router.get('/:id', pc.getPayment);
  router.post('/', pc.createPayment);
  router.put('/:id', pc.updatePayment);
  router.delete('/:id', pc.deletePayment);
  return router;
}
