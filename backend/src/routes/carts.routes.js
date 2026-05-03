import { Router } from 'express';
import * as c from '../controllers/carts.controller.js';

const router = Router();
router.get('/audit', c.auditCarts);
router.get('/user/:userId', c.getUserCart);
router.post('/', c.createOrGetCart);
router.post('/:cartId/checkout', c.checkoutCart);
router.delete('/:cartId', c.abandonCart);
router.post('/:cartId/items', c.addCartItem);
router.put('/:cartId/items/:itemId', c.updateCartItemQty);
router.delete('/:cartId/items/:itemId', c.deleteCartLine);

export default router;
