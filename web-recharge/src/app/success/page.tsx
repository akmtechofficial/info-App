"use client";

import { useEffect, useState, useRef, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { onAuthStateChanged, User } from "firebase/auth";
import {
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
} from "firebase/firestore";
import { auth, db } from "@/lib/firebase";
import { CheckCircle2, Clock, RefreshCw, Sparkles, ArrowLeft } from "lucide-react";

function SuccessPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();

  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [authLoading, setAuthLoading] = useState(true);

  const [verifying, setVerifying] = useState(true);
  const [isSuccess, setIsSuccess] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [countdown, setCountdown] = useState(5);

  const [creditsAdded, setCreditsAdded] = useState<number>(0);
  const [amountPaid, setAmountPaid] = useState<number>(0);
  const [orderId, setOrderId] = useState<string>("");

  const processedRef = useRef(false);

  // 1. Auth Listener
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setCurrentUser(user);
      setAuthLoading(false);
    });
    return () => unsubscribe();
  }, []);

  // 2. Verification & Credit Fulfillment Routine
  const verifyAndFulfill = async (targetUid: string, orderIdVal: string, creditsVal: number, amountVal: number) => {
    setVerifying(true);
    setErrorMessage(null);

    try {
      // Check if order was already fulfilled in Firestore
      const orderRef = doc(db, "orders", orderIdVal);
      const orderSnap = await getDoc(orderRef);

      if (orderSnap.exists() && orderSnap.data().status === "SUCCESS") {
        setIsSuccess(true);
        setVerifying(false);
        return;
      }

      // Verify with Payflux API
      const res = await fetch("/api/payflux/verify-order", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ orderId: orderIdVal }),
      });

      const data = await res.json();

      if (data.success && data.status === "SUCCESS") {
        // Atomically fulfill credits in Firestore
        const userRef = doc(db, "users", targetUid);

        await runTransaction(db, async (transaction) => {
          const userSnap = await transaction.get(userRef);
          const currentCredits = userSnap.exists()
            ? userSnap.data().credits || 0
            : 0;

          transaction.update(userRef, {
            credits: currentCredits + creditsVal,
            updatedAt: serverTimestamp(),
          });

          transaction.set(orderRef, {
            userId: targetUid,
            orderId: orderIdVal,
            amount: amountVal,
            creditsAdded: creditsVal,
            status: "SUCCESS",
            paymentGateway: "Payflux",
            timestamp: serverTimestamp(),
          });
        });

        setIsSuccess(true);
      } else {
        setIsSuccess(false);
        setErrorMessage(
          data.message ||
            "Payment status is currently PENDING on Payflux."
        );
      }
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Verification error:", error);
      setIsSuccess(false);
      setErrorMessage("Error verifying payment: " + (error.message || "Unknown error"));
    } finally {
      setVerifying(false);
    }
  };

  // 3. Process URL Params & Trigger Auto Verification
  useEffect(() => {
    const ordId = searchParams.get("orderId") || "";
    const creds = parseInt(searchParams.get("credits") || "0", 10);
    const amt = parseFloat(searchParams.get("amount") || "0");
    const targetUid = searchParams.get("uid") || currentUser?.uid || "";

    setOrderId(ordId);
    setCreditsAdded(creds);
    setAmountPaid(amt);

    if (processedRef.current) return;

    if (ordId && targetUid) {
      processedRef.current = true;
      verifyAndFulfill(targetUid, ordId, creds > 0 ? creds : 1, amt > 0 ? amt : 40);
    } else if (!authLoading && currentUser && ordId) {
      processedRef.current = true;
      verifyAndFulfill(currentUser.uid, ordId, creds > 0 ? creds : 1, amt > 0 ? amt : 40);
    } else if (!authLoading && !ordId) {
      setVerifying(false);
      setErrorMessage("No valid order ID found in return URL.");
    }
  }, [authLoading, currentUser, searchParams]);

  // 4. Auto Redirect Countdown Timer on Success
  useEffect(() => {
    if (!isSuccess) return;

    const timer = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          clearInterval(timer);
          router.push("/");
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(timer);
  }, [isSuccess, router]);

  const targetUid = searchParams.get("uid") || currentUser?.uid || "";

  return (
    <main className="min-h-screen bg-[#0B0F17] text-slate-100 flex flex-col items-center justify-center p-4 selection:bg-cyan-500 selection:text-black">
      <div className="w-full max-w-md glass-card rounded-3xl p-8 border border-cyan-500/30 text-center relative overflow-hidden shadow-2xl">
        <div className="absolute -right-16 -top-16 h-48 w-48 bg-cyan-500/10 rounded-full blur-3xl pointer-events-none"></div>
        <div className="absolute -left-16 -bottom-16 h-48 w-48 bg-purple-500/10 rounded-full blur-3xl pointer-events-none"></div>

        {verifying ? (
          <div className="py-10 space-y-4">
            <div className="h-16 w-16 mx-auto rounded-2xl bg-cyan-500/20 border border-cyan-500/40 flex items-center justify-center text-cyan-400">
              <RefreshCw className="h-8 w-8 animate-spin" />
            </div>
            <h2 className="text-xl font-bold text-white">Verifying Payflux Payment...</h2>
            <p className="text-xs text-slate-400">
              Connecting to Payflux engine and updating your Firestore credits balance.
            </p>
          </div>
        ) : isSuccess ? (
          <div className="py-4 space-y-5">
            <div className="h-20 w-20 mx-auto rounded-full bg-gradient-to-tr from-emerald-500 to-teal-400 p-0.5 shadow-xl shadow-emerald-500/30 animate-pulse">
              <div className="h-full w-full rounded-full bg-[#0B0F17] flex items-center justify-center">
                <CheckCircle2 className="h-10 w-10 text-emerald-400" />
              </div>
            </div>

            <div>
              <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-bold uppercase tracking-wider bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 mb-2">
                <Sparkles className="h-3.5 w-3.5" /> Payment Verified & Credited
              </span>
              <h1 className="text-2xl font-extrabold text-white tracking-tight">
                PAYMENT SUCCESSFUL
              </h1>
              <p className="text-xs text-slate-400 mt-1">
                Order ID: <span className="font-mono text-cyan-400">{orderId}</span>
              </p>
            </div>

            <div className="glass-panel p-4 rounded-2xl border border-white/10 space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-slate-400">Amount Paid:</span>
                <span className="font-bold text-white">₹{amountPaid}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-slate-400">Credits Added:</span>
                <span className="font-extrabold text-cyan-400">+{creditsAdded} Credits</span>
              </div>
            </div>

            <div className="p-3 rounded-xl bg-cyan-500/10 border border-cyan-500/30 text-xs font-semibold text-cyan-300">
              RETURNING TO HOME PAGE IN {countdown} SECONDS...
            </div>

            <button
              onClick={() => router.push("/")}
              className="w-full py-3.5 rounded-xl btn-gradient text-xs uppercase tracking-wider font-extrabold flex items-center justify-center gap-2 shadow-lg shadow-cyan-500/20"
            >
              <ArrowLeft className="h-4 w-4" /> RETURN TO HOME NOW
            </button>
          </div>
        ) : (
          <div className="py-4 space-y-5">
            <div className="h-16 w-16 mx-auto rounded-2xl bg-amber-500/20 border border-amber-500/40 flex items-center justify-center text-amber-400">
              <Clock className="h-8 w-8 animate-pulse" />
            </div>

            <div>
              <h2 className="text-xl font-bold text-white">Payment Pending / Incomplete</h2>
              <p className="text-xs text-amber-300/80 mt-2 px-2 leading-relaxed">
                {errorMessage}
              </p>
            </div>

            {targetUid && orderId && (
              <button
                onClick={() =>
                  verifyAndFulfill(
                    targetUid,
                    orderId,
                    creditsAdded > 0 ? creditsAdded : 1,
                    amountPaid > 0 ? amountPaid : 40
                  )
                }
                className="w-full py-3.5 rounded-xl bg-gradient-to-r from-amber-500 to-orange-500 text-black font-extrabold text-xs uppercase tracking-wider flex items-center justify-center gap-2 shadow-lg shadow-amber-500/20"
              >
                <RefreshCw className="h-4 w-4" /> RETRY VERIFICATION NOW
              </button>
            )}

            <button
              onClick={() => router.push("/")}
              className="w-full py-3 rounded-xl glass-panel text-slate-300 text-xs font-bold hover:text-white flex items-center justify-center gap-2"
            >
              <ArrowLeft className="h-4 w-4" /> BACK TO RECHARGE PORTAL
            </button>
          </div>
        )}
      </div>
    </main>
  );
}

export default function SuccessPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-[#0B0F17] flex items-center justify-center text-cyan-400 font-bold text-sm">
          Loading Success Page...
        </div>
      }
    >
      <SuccessPageContent />
    </Suspense>
  );
}
