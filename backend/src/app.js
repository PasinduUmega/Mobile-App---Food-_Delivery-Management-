import express from 'express';
import cors from 'cors';
import { paypalClient as makePayPal } from './paypal.js';
import { registerRoutes } from './routes/index.js';

export function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  const paypalHttpClient = (() => {
    try {
      return makePayPal();
    } catch (e) {
      console.error('PayPal Initialization Error:', e.message);
      return null;
    }
  })();

  registerRoutes(app, { paypalClient: paypalHttpClient });
  return app;
}
