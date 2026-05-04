import { Router } from 'express';
import * as menu from '../controllers/menuManagement.controller.js';

const router = Router();
router.get('/', menu.listMenuItems);
router.get('/:id', menu.getMenuItem);
router.post('/', menu.createMenuItem);
router.put('/:id', menu.updateMenuItem);
router.delete('/:id', menu.deleteMenuItem);

export default router;
