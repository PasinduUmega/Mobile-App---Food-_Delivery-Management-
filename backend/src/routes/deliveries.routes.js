import { Router } from 'express';
import * as d from '../controllers/deliveries.controller.js';

const router = Router();
router.get('/', d.listDeliveries);
router.post('/', d.createDelivery);
router.put('/:id', d.updateDelivery);
router.delete('/:id', d.deleteDelivery);

export default router;
