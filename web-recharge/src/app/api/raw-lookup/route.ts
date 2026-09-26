import { NextResponse } from "next/server";

const PAN_TO_GST_URL = process.env.RAW_PAN_URL || "";
const AADHAAR_INFO_URL = process.env.RAW_AADHAAR_URL || "";
const RC_INFO_URL = process.env.RAW_RC_URL || "";

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const queryType = searchParams.get("type");
    const queryValue = searchParams.get("query");

    if (!queryType || !queryValue) {
      return NextResponse.json(
        { success: false, error: "Missing 'type' or 'query' parameters." },
        { status: 400 }
      );
    }

    // Basic Security: Verify the custom API key sent by the Flutter app
    const apiKey = req.headers.get("x-api-key");
    if (apiKey !== "INFO_APP_SECRET_2026") {
      return NextResponse.json(
        { success: false, error: "Unauthorized request. Invalid API Key." },
        { status: 401 }
      );
    }

    let fetchUrl = "";
    if (queryType === "PAN") {
      fetchUrl = `${PAN_TO_GST_URL}${encodeURIComponent(queryValue)}`;
    } else if (queryType === "Aadhaar") {
      fetchUrl = `${AADHAAR_INFO_URL}${encodeURIComponent(queryValue)}`;
    } else if (queryType === "RC") {
      fetchUrl = `${RC_INFO_URL}${encodeURIComponent(queryValue)}`;
    } else {
      return NextResponse.json(
        { success: false, error: `Unknown query type: ${queryType}` },
        { status: 400 }
      );
    }

    // Proxy the request securely
    const response = await fetch(fetchUrl, {
      cache: "no-store",
      headers: {
        Accept: "application/json",
      },
    });

    if (!response.ok) {
      throw new Error(`External API returned status: ${response.status}`);
    }

    const data = await response.json();
    
    return NextResponse.json(data);
  } catch (error: unknown) {
    const err = error as Error;
    console.error("Raw Lookup Route Error:", err);
    return NextResponse.json(
      { success: false, error: err.message || "Failed to fetch data from proxy." },
      { status: 500 }
    );
  }
}
