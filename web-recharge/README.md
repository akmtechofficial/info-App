# Info App - Web Recharge Portal (`web-recharge`)

A Next.js 15 application providing a secure, web-only payment checkout experience powered by Payflux Payment Gateway and Firebase Firestore.

---

## 🚀 Features

- **Web-Only Checkout**: Centralized hosted web portal for credits purchase and account recharge.
- **Payflux Integration**: Secure server-side order creation and hosted checkout redirection.
- **Dynamic Merchant Domain**: Configurable origin support via `NEXT_PUBLIC_SITE_URL` for multi-tenant or multi-domain deployments.
- **Firebase Firestore Integration**: Real-time user credit account updating.

---

## ⚙️ Environment Variables

Create a `.env.local` or `.env` file in the root directory:

```env
# Dynamic Site Domain (e.g. https://info-app-recharge-tawny.vercel.app or custom merchant domain)
NEXT_PUBLIC_SITE_URL=https://info-app-recharge-tawny.vercel.app

# Payflux Gateway Credentials
PAYFLUX_BASE_URL=https://fampay-merchant-api.onrender.com
PAYFLUX_API_KEY=akm_Z_live_your_key_here

# Firebase Web App Config
NEXT_PUBLIC_FIREBASE_API_KEY=...
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=...
NEXT_PUBLIC_FIREBASE_PROJECT_ID=...
```

---

## 🛠️ Getting Started

First, install dependencies and start the development server:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser.

---

## 🌐 Deploying to Vercel

Deploy this Next.js app to Vercel or any Node.js hosting platform:
1. Set the environment variables in your Vercel project dashboard.
2. Set `NEXT_PUBLIC_SITE_URL` to your production domain (e.g. `https://your-domain.vercel.app`).
