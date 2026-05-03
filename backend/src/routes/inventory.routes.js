import { Router } from 'express';
import * as cat from '../controllers/catalog.controller.js';

const router = Router();
router.get('/', cat.listInventory);
router.post('/', cat.createInventory);
router.put('/:id', cat.updateInventory);
router.delete('/:id', cat.deleteInventory);

export default router;
