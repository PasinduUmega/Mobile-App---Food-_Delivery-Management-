import { Router } from 'express';
import * as u from '../controllers/users.controller.js';
import * as order from '../controllers/order.controller.js';

const router = Router();
router.get('/', u.listUsers);
router.post('/', u.createUser);
router.get('/:userId/orders', order.listOrdersForUser);
router.get('/:id', u.getUser);
router.put('/:id', u.updateUser);
router.delete('/:id', u.deleteUser);

export default router;
