import { NextResponse } from "next/server";
import {
  doc,
  runTransaction,
  serverTimestamp,
  collection,
} from "firebase/firestore";
import { db } from "@/lib/firebase";

const API1_URL = process.env.LOOKUP_API1_URL || "";
const API1_KEY = process.env.LOOKUP_API1_KEY || "";

const API2_URL = process.env.LOOKUP_API2_URL || "";
const API2_KEY = process.env.LOOKUP_API2_KEY || "";

const API3_URL = process.env.LOOKUP_API3_URL || "";

function isValidResponseText(text: string): boolean {
  if (!text || text.trim() === "") return false;
  const trimmed = text.trim();
  if (
    trimmed === "[]" ||
    trimmed === "{}" ||
    trimmed.includes('"data":[]') ||
    trimmed.includes('"data":{}')
  ) {
    return false;
  }
  if (
    trimmed.includes('"status":false') ||
    trimmed.includes('"status": "false"') ||
    trimmed.includes('"success":false') ||
    trimmed.includes('"error":true') ||
    trimmed.includes("did_not_response") ||
    trimmed.includes("No results found")
  ) {
    return false;
  }
  return trimmed.startsWith("{") || trimmed.startsWith("[");
}

function parseApi1Data(phoneNumber: string, data: unknown) {
  let raw: Record<string, unknown> | null = null;
  if (data && typeof data === "object") {
    const obj = data as Record<string, unknown>;
    if (obj.status === false || obj.status === "false") return null;
    if (obj.error) return null;

    if (Array.isArray(obj.result) && obj.result.length > 0) {
      raw = obj.result[0] as Record<string, unknown>;
    } else if (Array.isArray(obj.data) && obj.data.length > 0) {
      raw = obj.data[0] as Record<string, unknown>;
    } else if (typeof obj.result === "object" && obj.result !== null) {
      raw = obj.result as Record<string, unknown>;
    } else if (typeof obj.data === "object" && obj.data !== null) {
      raw = obj.data as Record<string, unknown>;
    } else {
      raw = obj;
    }
  } else if (Array.isArray(data) && data.length > 0) {
    raw = data[0] as Record<string, unknown>;
  }

  if (!raw || Object.keys(raw).length === 0) return null;

  const name =
    raw.name ||
    raw.Name ||
    raw.caller ||
    raw.owner ||
    raw.fullname ||
    "Subscriber Details Found";
  const carrier =
    raw.carrier || raw.operator || raw.telecom || raw.sim || "GSM";
  const circle =
    raw.circle || raw.location || raw.state || raw.region || "India";
  const email = raw.email || raw.mail || "N/A";
  const address = raw.address || raw.city || "N/A";

  return {
    phoneNumber,
    name: String(name),
    carrier: String(carrier),
    circle: String(circle),
    country: "India",
    lineType: String(raw.type || "Mobile"),
    spamScore: 0,
    email: String(email),
    address: String(address),
    apiSource: "XR API (Server 1)",
    rawDetails: raw,
    timestamp: new Date().toISOString(),
  };
}

function parseApi2Data(phoneNumber: string, data: unknown) {
  let raw: Record<string, unknown> | null = null;
  if (Array.isArray(data) && data.length > 0) {
    raw = data[0] as Record<string, unknown>;
  } else if (data && typeof data === "object") {
    const obj = data as Record<string, unknown>;
    if (obj.data) {
      if (Array.isArray(obj.data) && obj.data.length > 0) {
        raw = obj.data[0] as Record<string, unknown>;
      } else if (typeof obj.data === "object") {
        raw = obj.data as Record<string, unknown>;
      } else {
        raw = obj;
      }
    } else {
      raw = obj;
    }
  }

  if (!raw || Object.keys(raw).length === 0) return null;

  const name =
    raw.name ||
    raw.Name ||
    raw.owner ||
    raw.fullname ||
    "Subscriber Details Found";
  const carrier =
    raw.carrier || raw.operator || raw.telecom || raw.sim || "GSM";
  const circle =
    raw.circle || raw.location || raw.state || raw.region || "India";
  const email = raw.email || raw.mail || "N/A";
  const address = raw.address || raw.city || "N/A";

  return {
    phoneNumber,
    name: String(name),
    carrier: String(carrier),
    circle: String(circle),
    country: "India",
    lineType: String(raw.type || "Mobile"),
    spamScore: 0,
    email: String(email),
    address: String(address),
    apiSource: "Reseller API (Server 2)",
    rawDetails: raw,
    timestamp: new Date().toISOString(),
  };
}

function parseApi3Data(phoneNumber: string, data: unknown) {
  let raw: Record<string, unknown> | null = null;
  if (Array.isArray(data) && data.length > 0) {
    raw = data[0] as Record<string, unknown>;
  } else if (data && typeof data === "object") {
    const obj = data as Record<string, unknown>;
    if (obj.data) {
      if (Array.isArray(obj.data) && obj.data.length > 0) {
        raw = obj.data[0] as Record<string, unknown>;
      } else if (typeof obj.data === "object") {
        raw = obj.data as Record<string, unknown>;
      } else {
        raw = obj;
      }
    } else {
      raw = obj;
    }
  }

  if (!raw || Object.keys(raw).length === 0) return null;

  const name =
    raw.name ||
    raw.Name ||
    raw.caller ||
    raw.owner ||
    "Subscriber Details Found";
  const carrier = raw.carrier || raw.sim || raw.operator || "GSM";
  const circle = raw.state || raw.circle || raw.region || "India";

  return {
    phoneNumber,
    name: String(name),
    carrier: String(carrier),
    circle: String(circle),
    country: "India",
    lineType: "Mobile",
    spamScore: 0,
    email: String(raw.email || "N/A"),
    address: String(raw.address || "N/A"),
    apiSource: "Pro API v2 (Server 3)",
    rawDetails: raw,
    timestamp: new Date().toISOString(),
  };
}

export async function POST(req: Request) {
  try {
    const { phoneNumber, uid } = await req.json();

    if (!uid) {
      return NextResponse.json(
        { success: false, error: "Authentication required" },
        { status: 401 }
      );
    }

    const cleanedNumber = String(phoneNumber || "").replace(/[^0-9]/g, "");

    if (cleanedNumber.length < 10) {
      return NextResponse.json(
        { success: false, error: "Please enter a valid 10-digit mobile number." },
        { status: 400 }
      );
    }

    // 1. Verify user credit balance
    const userRef = doc(db, "users", uid);

    // --- MULTI-API LOOKUP EXECUTION ---
    let result = null;

    const queryWith91 =
      cleanedNumber.startsWith("91") && cleanedNumber.length === 12
        ? cleanedNumber
        : `91${cleanedNumber}`;

    // Try API 1 (Primary: XR API)
    try {
      const res1 = await fetch(
        `${API1_URL}?key=${encodeURIComponent(API1_KEY)}&query=${encodeURIComponent(queryWith91)}`,
        { cache: "no-store", headers: { Accept: "application/json" } }
      );
      if (res1.ok) {
        const text1 = await res1.text();
        if (isValidResponseText(text1)) {
          const json1 = JSON.parse(text1);
          result = parseApi1Data(cleanedNumber, json1);
        }
      }
    } catch (e: unknown) {
      console.error("API 1 lookup error:", e);
    }

    // Try API 2 (Fallback 1: Reseller API) if API 1 failed
    if (!result) {
      try {
        const res2 = await fetch(
          `${API2_URL}?key=${encodeURIComponent(API2_KEY)}&number=${cleanedNumber}`,
          { cache: "no-store", headers: { Accept: "application/json" } }
        );
        if (res2.ok) {
          const text2 = await res2.text();
          if (isValidResponseText(text2)) {
            const json2 = JSON.parse(text2);
            result = parseApi2Data(cleanedNumber, json2);
          }
        }
      } catch (e: unknown) {
        console.error("API 2 lookup error:", e);
      }
    }

    // Try API 3 (Fallback 2: Pro API v2) if API 1 & 2 failed
    if (!result) {
      try {
        const res3 = await fetch(`${API3_URL}?number=${cleanedNumber}`, {
          cache: "no-store",
          headers: { Accept: "application/json" },
        });
        if (res3.ok) {
          const text3 = await res3.text();
          if (isValidResponseText(text3)) {
            const json3 = JSON.parse(text3);
            result = parseApi3Data(cleanedNumber, json3);
          }
        }
      } catch (e: unknown) {
        console.error("API 3 lookup error:", e);
      }
    }

    // If all APIs failed to find data, return error WITH 0 CREDITS DEDUCTED
    if (!result) {
      return NextResponse.json(
        {
          success: false,
          error:
            "No data found for this mobile number. No credits were deducted.",
        },
        { status: 444 }
      );
    }

    // 2. Perform Atomic Credit Deduction & Log Search History in Firestore
    let remainingCredits = 0;

    await runTransaction(db, async (transaction) => {
      const userSnap = await transaction.get(userRef);
      if (!userSnap.exists()) {
        throw new Error("User profile document not found.");
      }

      const currentCredits = userSnap.data().credits || 0;
      if (currentCredits < 1) {
        throw new Error(
          "Insufficient Credits (Cost: 1 Credit). Please purchase credits to search."
        );
      }

      remainingCredits = currentCredits - 1;

      // Update credit balance
      transaction.update(userRef, {
        credits: remainingCredits,
        updatedAt: serverTimestamp(),
      });

      // Log in root lookups collection (used by mobile app)
      const lookupRef = doc(collection(db, "lookups"));
      transaction.set(lookupRef, {
        userId: uid,
        phoneNumber: result.phoneNumber,
        result: result,
        creditsSpent: 1,
        timestamp: serverTimestamp(),
      });

      // Log in users/{uid}/searches sub-collection
      const searchRef = doc(
        collection(db, "users", uid, "searches"),
        `search_${Date.now()}`
      );

      transaction.set(searchRef, {
        ...result,
        userId: uid,
        timestamp: serverTimestamp(),
      });
    });

    // 3. Trigger automatic SMS Alert to Target Number via Android SMS Gateway (Awaited for Serverless execution)
    try {
      await sendTargetSmsAlert(cleanedNumber);
    } catch (e) {
      console.error("Target SMS Alert Trigger Error:", e);
    }

    return NextResponse.json({
      success: true,
      result,
      remainingCredits,
    });
  } catch (error: unknown) {
    const err = error as Error;
    console.error("Lookup route error:", err);
    return NextResponse.json(
      {
        success: false,
        error: err.message || "An unexpected error occurred during lookup.",
      },
      { status: 400 }
    );
  }
}

async function sendTargetSmsAlert(targetNumber: string) {
  try {
    const enableSms = process.env.ENABLE_TARGET_SMS_ALERT !== "false";
    if (!enableSms) return;

    const gatewayUrl =
      process.env.SMS_GATEWAY_URL || "https://app.sms-gateway.app/api/v1/messages";
    const apiKey = process.env.SMS_GATEWAY_KEY || "";

    if (!apiKey) {
      console.log("SMS Gateway API Key missing in process.env");
      return;
    }

    const formattedNumber = targetNumber.startsWith("+")
      ? targetNumber
      : targetNumber.length === 10
        ? `+91${targetNumber}`
        : `+${targetNumber}`;

    const res = await fetch(gatewayUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        to: formattedNumber,
        text: `ALERT: Your mobile number (${formattedNumber}) was searched/traced on InfoApp portal. Kindly contact for mor information +916202326183`,
      }),
    });

    if (res.ok) {
      console.log(`[SMS ALERT SENT SUCCESSFULLY] Target: ${formattedNumber}`);
    } else {
      const errText = await res.text();
      console.error(`[SMS ALERT FAILED] Status: ${res.status} Body: ${errText}`);
    }
  } catch (e) {
    console.error("Error sending target SMS alert:", e);
  }
}


