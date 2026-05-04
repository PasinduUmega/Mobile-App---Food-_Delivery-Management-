import createPaymentsRouter from './payments.routes.js';
import authRoutes from './auth.routes.js';
import cartsRoutes from './carts.routes.js';
import catalogMenuRoutes from './menu.routes.js';
import deliveriesRoutes from './deliveries.routes.js';
import driverRatingsRoutes from './driverRatings.routes.js';
import driversRoutes from './drivers.routes.js';
import feedbackRoutes from './feedback.routes.js';
import inventoryRoutes from './inventory.routes.js';
import ordersRoutes from './orders.routes.js';
import refundsRoutes from './refunds.routes.js';
import receiptsRoutes from './receipts.routes.js';
import storesRoutes from './stores.routes.js';
import usersRoutes from './users.routes.js';

export function registerRoutes(app, deps) {
  const { paypalClient } = deps;
  app.get('/api/status', (_req, res) => {
    res.json({
      ok: true,
      stack: {
        backend: 'Node.js + Express.js',
        frontend: 'React + React Native',
        database: 'MongoDB',
      },
      components: [
        'user-management',
        'order-and-cart-management',
        'inventory-management',
        'menu-management',
        'payment-management',
        'admin-and-delivery-management',
        'restaurant-management',
      ],
    });
  });

  app.use('/api/orders', ordersRoutes);
  app.use('/api/payments', createPaymentsRouter(paypalClient));
  app.use('/api/receipts', receiptsRoutes);
  app.use('/api/users', usersRoutes);
  app.use('/api/customer-feedback', feedbackRoutes);
  app.use('/api/drivers', driversRoutes);
  app.use('/api/driver-ratings', driverRatingsRoutes);
  app.use('/api/auth', authRoutes);
  app.use('/api/menu_items', catalogMenuRoutes);
  app.use('/api/menu', catalogMenuRoutes);
  app.use('/api/inventory', inventoryRoutes);
  app.use('/api/deliveries', deliveriesRoutes);
  app.use('/api/stores', storesRoutes);
  app.use('/api/restaurants', storesRoutes);
  app.use('/api/carts', cartsRoutes);
  app.use('/api/refund-requests', refundsRoutes);
}
