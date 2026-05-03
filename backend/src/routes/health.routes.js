import { Router } from 'express';
import * as h from '../controllers/health.controller.js';

const router = Router();
router.get('/health', h.health);

export default router;
