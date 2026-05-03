import { Router } from 'express';
import * as r from '../controllers/receipt.controller.js';

const router = Router();
router.get('/:orderId', r.getReceipt);

export default router;
