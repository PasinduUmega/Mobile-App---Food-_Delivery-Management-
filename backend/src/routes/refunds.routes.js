import { Router } from 'express';
import * as rf from '../controllers/refunds.controller.js';

const router = Router();
router.post('/', rf.createRefundRequest);
router.get('/', rf.listRefundRequests);
router.patch('/:id', rf.patchRefundRequest);

export default router;
