import paypal from '@paypal/checkout-server-sdk';

function paypalEnvironment() {
  const env = (process.env.PAYPAL_ENV || 'sandbox').toLowerCase();
  const clientId = process.env.PAYPAL_CLIENT_ID;
  const clientSecret = process.env.PAYPAL_CLIENT_SECRET;
  if (!clientId || !clientSecret || clientId.includes('REPLACE_WITH_YOUR_') || clientSecret.includes('REPLACE_WITH_YOUR_')) {
    throw new Error('PayPal credentials NOT CONFIGURED. Please add your actual Client ID and Secret to the .env file and restart the server.');
  }

  if (env === 'live') {
    return new paypal.core.LiveEnvironment(clientId, clientSecret);
  }
  return new paypal.core.SandboxEnvironment(clientId, clientSecret);
}

export function paypalClient() {
  return new paypal.core.PayPalHttpClient(paypalEnvironment());
}

export function buildCreateOrderRequest({ total, currency, returnUrl, cancelUrl }) {
  const request = new paypal.orders.OrdersCreateRequest();
  request.prefer('return=representation');
  request.requestBody({
    intent: 'CAPTURE',
    purchase_units: [
      {
        amount: {
          currency_code: currency,
          value: total.toFixed(2),
        },
      },
    ],
    application_context: {
      return_url: returnUrl,
      cancel_url: cancelUrl,
      user_action: 'PAY_NOW',
    },
  });
  return request;
}

export function buildCaptureOrderRequest(paypalOrderId) {
  return new paypal.orders.OrdersCaptureRequest(paypalOrderId);
}

