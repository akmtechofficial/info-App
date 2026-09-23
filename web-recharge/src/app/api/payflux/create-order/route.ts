import { NextResponse } from "next/server";

const PAYFLUX_BASE_URL =
  process.env.PAYFLUX_BASE_URL || "https://fampay-merchant-api.onrender.com";
const PAYFLUX_API_KEY = process.env.PAYFLUX_API_KEY || "";

export async function POST(req: Request) {
  try {
    const { amount, creditsToBuy, uid } = await req.json();

    if (!amount || amount <= 0) {
      return NextResponse.json(
        { success: false, error: "Invalid amount specified" },
        { status: 400 }
      );
    }

    const origin =
      req.headers.get("origin") ||
      req.headers.get("referer")?.replace(/\/$/, "") ||
      "http://localhost:3000";

    const credits = creditsToBuy || Math.max(1, Math.floor(amount / 40));
    const returnUrl = `${origin}/success?credits=${credits}&amount=${amount}&uid=${uid || ""}`;

    const payload = {
      apiKey: PAYFLUX_API_KEY,
      amount: Number(amount),
      returnUrl: returnUrl,
    };

    const res = await fetch(`${PAYFLUX_BASE_URL}/api/v1/orders`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const data = await res.json();

    if (!res.ok || !data.success) {
      console.error("Payflux API error response:", data);
      return NextResponse.json(
        {
          success: false,
          error: data.message || "Failed to create order with Payflux",
        },
        { status: res.status || 400 }
      );
    }

    let rawCheckoutUrl: string = data.data?.checkoutUrl || "";
    const orderId = data.data?.orderId || data.data?.id;

    if (!rawCheckoutUrl) {
      return NextResponse.json(
        { success: false, error: "No checkout URL returned from Payflux" },
        { status: 500 }
      );
    }

    // Force replace localhost or relative links with actual Payflux server URL
    if (rawCheckoutUrl.startsWith("/")) {
      rawCheckoutUrl = `${PAYFLUX_BASE_URL}${rawCheckoutUrl}`;
    } else {
      rawCheckoutUrl = rawCheckoutUrl
        .replaceAll("http://localhost:3000", PAYFLUX_BASE_URL)
        .replaceAll("https://localhost:3000", PAYFLUX_BASE_URL)
        .replaceAll("http://localhost:3001", PAYFLUX_BASE_URL)
        .replaceAll("https://localhost:3001", PAYFLUX_BASE_URL)
        .replaceAll("http://127.0.0.1:3000", PAYFLUX_BASE_URL)
        .replaceAll("https://127.0.0.1:3000", PAYFLUX_BASE_URL);
    }

    const finalReturnUrl = `${returnUrl}&orderId=${orderId}`;

    return NextResponse.json({
      success: true,
      checkoutUrl: rawCheckoutUrl,
      orderId,
      checkoutToken: data.data?.checkoutToken || orderId,
      merchantName: data.data?.merchantName || data.data?.businessName || "InfoApp Recharge",
      upiId: data.data?.upiId || data.data?.payeeVpa || data.data?.vpa || null,
      amount: data.data?.amount || amount,
      mode: data.data?.mode || "live",
      returnUrl: finalReturnUrl,
    });
  } catch (error: unknown) {
    const err = error as Error;
    console.error("Payflux order error:", err);
    return NextResponse.json(
      {
        success: false,
        error: err.message || "Internal server error connecting to Payflux",
      },
      { status: 500 }
    );
  }
}
