import { Router } from 'express';
import * as s from '../controllers/stores.controller.js';
import * as cat from '../controllers/catalog.controller.js';
import * as order from '../controllers/order.controller.js';

const router = Router();
router.get('/', s.listStores);
router.post('/', s.createStore);
router.get('/:id/menu', cat.getStoreMenu);
router.get('/:storeId/orders', order.listOrdersForStore);
router.get('/:id', s.getStore);
router.put('/:id', s.updateStore);
router.delete('/:id', s.deleteStore);

export default router;
