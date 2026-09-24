I want to integrate the Payflux payment gateway into my project. Here are the complete details:

## Payflux API Details
- Base URL: https://fampay-merchant-api.onrender.com
- Payment Flow: Server-side order creation → Redirect to hosted checkout → UPI QR payment → Auto-verification via IMAP → Webhook notification

## Complete Integration Steps:

### 1. Create Payment Order (Server-Side)
POST https://fampay-merchant-api.onrender.com/api/v1/orders
Body: { apiKey: "YOUR_API_KEY", amount: 500, currency: "INR", customerEmail: "user@email.com", customerName: "User Name", returnUrl: "https://your-site.com/success" }
Response: { success: true, data: { id: "order_id", checkoutUrl: "https://..." } }

### 2. Redirect User to Checkout
Take checkoutUrl from response and redirect browser: window.location.href = data.data.checkoutUrl
The checkout page shows UPI QR code. Payment is auto-verified.

### 3. Verify Payment (Server-Side)
POST https://fampay-merchant-api.onrender.com/api/v1/payments/verify
Body: { apiKey: "YOUR_API_KEY", orderId: "order_id_from_step1" }
Response: { success: true, data: { status: "SUCCESS" | "PENDING" | "FAILED" } }

### 4. Webhook (Optional but Recommended)
Set webhook URL in Dashboard > Webhooks
We POST to your URL with: { event: "payment.success", payload: { order: {...}, transaction: {...} } }
Verify signature using x-payflux-signature header with HMAC-SHA256

## Important Rules:
- Never expose API key in frontend code, always call from backend
- Use TEST keys during development, LIVE keys in production
- Always verify payment server-side before granting access
- Set up webhooks as backup for redirect failures
- In Test Mode (when using sk_test_ keys), the checkout page will show a "Simulate Success" button instead of a QR code. Click it to simulate a successful payment.