import { Router } from 'express';
import * as fb from '../controllers/customerFeedback.controller.js';

const router = Router();
router.post('/', fb.createFeedback);
router.get('/me', fb.listFeedbackMe);
router.get('/', fb.listFeedbackAdmin);

export default router;
