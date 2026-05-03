import { Router } from 'express';
import * as cat from '../controllers/catalog.controller.js';

const router = Router();
router.post('/', cat.createMenuItem);
router.put('/:id', cat.updateMenuItem);
router.delete('/:id', cat.deleteMenuItem);

export default router;
