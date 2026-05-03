import { Router } from 'express';
import * as order from '../controllers/order.controller.js';

const router = Router();
router.post('/', order.createOrder);
router.get('/', order.listOrders);
router.get('/:id', order.getOrder);
router.put('/:id', order.updateOrder);
router.delete('/:id', order.deleteOrder);

export default router;
