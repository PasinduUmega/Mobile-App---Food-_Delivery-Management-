import { Router } from 'express';
import * as a from '../controllers/auth.controller.js';

const router = Router();
router.post('/signup', a.signup);
router.post('/signin', a.signin);

export default router;
