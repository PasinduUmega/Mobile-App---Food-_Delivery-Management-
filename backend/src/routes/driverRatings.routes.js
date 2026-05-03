import { Router } from 'express';
import * as dr from '../controllers/drivers.controller.js';

const router = Router();
router.get('/', dr.listDriverRatings);
router.post('/', dr.createDriverRating);
router.put('/:id', dr.updateDriverRating);

export default router;
