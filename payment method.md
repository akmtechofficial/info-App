# Payflux Payment Gateway Integration Documentation (Web-Only)

This document describes the Web-Only integration architecture for Payflux Payment Gateway. Native application SDKs have been retired in favor of secure, centralized hosted web checkout portals.

---

## 1. Architecture Overview

- **Native App Strategy**: Native SDKs and embedded in-app payment modal dialogs are not used. The Flutter app (or any native app) redirects users directly to the official Web Checkout Portal.
- **Hosted Web Portal**: Next.js Web Recharge application (`web-recharge`) handles order creation, user Firestore credit balance updating, and Payflux hosted checkout redirection.
- **Dynamic Origin Resolution**: All origin links use `NEXT_PUBLIC_SITE_URL` dynamically so any merchant can host the portal on their own domain or environment.

---

## 2. Payflux API Details

- **Base URL**: `https://fampay-merchant-api.onrender.com`
- **Portal Base URL**: Configured via `NEXT_PUBLIC_SITE_URL` (e.g. `https://info-app-recharge-tawny.vercel.app`)
- **Payment Flow**: 
  1. Native Mobile / Web App → Opens Web Portal (`/dashboard?uid={USER_ID}`)
  2. Web Portal → Calls Server-side Order Creation (`POST /api/payflux/create-order`)
  3. Payflux API → Returns `checkoutUrl` with UPI QR / App sheet link
  4. User completes payment on Payflux hosted checkout page
  5. Auto-verification via IMAP / Webhook → Credits user balance in Firestore
  6. Redirect back to Web Portal `/success` page

---

## 3. Environment Configuration (`.env`)

For Next.js `web-recharge`:

```env
# Site URL Configuration (Dynamic Domain for Merchants)
NEXT_PUBLIC_SITE_URL=https://info-app-recharge-tawny.vercel.app

# Payflux API Credentials
PAYFLUX_BASE_URL=https://fampay-merchant-api.onrender.com
PAYFLUX_API_KEY=your_payflux_api_key_here

# Firebase Web Config
NEXT_PUBLIC_FIREBASE_API_KEY=your_firebase_api_key
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=your_project.firebaseapp.com
NEXT_PUBLIC_FIREBASE_PROJECT_ID=your_project_id
```

---

## 4. Flutter Integration Example

In Flutter, launch the web checkout portal using `url_launcher`:

```dart
import 'package:url_launcher/url_launcher.dart';

Future<void> openWebRechargePortal(String userUid) async {
  final url = 'https://info-app-recharge-tawny.vercel.app/dashboard?uid=$userUid';
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

---

## 5. Security & Verification Rules

1. **Never expose API keys** in client-side native code or frontend JavaScript.
2. **Server-Side Order Creation**: Orders are created securely via backend API route (`/api/payflux/create-order`).
3. **Firestore Security**: User credits are updated server-side or via verified return flow.