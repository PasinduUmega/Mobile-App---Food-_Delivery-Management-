import { Router } from 'express';
import * as d from '../controllers/drivers.controller.js';

const router = Router();
router.get('/', d.listDrivers);
router.post('/', d.createDriver);
router.get('/metrics/leaderboard', d.driverLeaderboard);
router.get('/:driverId/metrics', d.driverMetrics);
router.get('/:id', d.getDriver);
router.put('/:id', d.updateDriver);
router.delete('/:id', d.deleteDriver);

export default router;
