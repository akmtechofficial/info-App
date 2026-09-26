"use client";

import { useEffect, useState, useRef, Suspense } from "react";
import {
  onAuthStateChanged,
  GoogleAuthProvider,
  signInWithPopup,
  signOut,
  User,
} from "firebase/auth";
import {
  doc,
  onSnapshot,
  setDoc,
  collection,
  query,
  where,
  serverTimestamp,
  getDoc,
  runTransaction,
} from "firebase/firestore";
import { auth, db } from "@/lib/firebase";
import { useRouter, useSearchParams } from "next/navigation";
import {
  Zap,
  CreditCard,
  History,
  User as UserIcon,
  LogOut,
  Sparkles,
  RefreshCw,
  CheckCircle2,
  XCircle,
  PartyPopper,
  Clock,
  LayoutDashboard,
  Search,
  Phone,
  MapPin,
  Mail,
  Copy,
  Check,
  ShieldAlert,
  Download,
  Smartphone,
  X,
} from "lucide-react";

declare global {
  interface Window {
    Payflux?: {
      checkout?: (options: {
        orderId: string;
        checkoutToken?: string;
        baseUrl?: string;
        name?: string;
        handler?: (result: { orderId: string; paymentId?: string; status: string }) => void;
        onSuccess?: (result: { orderId: string; paymentId?: string; status: string }) => void;
        onError?: (error: { code?: string; message: string }) => void;
        onClose?: () => void;
      }) => void;
      open?: (options: {
        orderId: string;
        checkoutToken?: string;
        name?: string;
        onSuccess?: (result: { orderId: string; paymentId?: string; status: string }) => void;
        onFailure?: (error: { code?: string; message: string }) => void;
        onClose?: () => void;
      }) => void;
    };
    PaySaaS?: Window["Payflux"];
  }
}

interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  credits: number;
  customPricePerCredit?: number;
}

interface OrderRecord {
  id: string;
  orderId: string;
  amount: number;
  creditsAdded: number;
  status: string;
  timestamp?: { seconds?: number } | null;
}

interface CreditPackPlan {
  id: string;
  title: string;
  credits: number;
  price: number;
  tag?: string;
  desc?: string;
  recommended?: boolean;
}

interface SearchRecord {
  id: string;
  phoneNumber: string;
  name: string;
  carrier: string;
  circle: string;
  country: string;
  lineType: string;
  email: string;
  address: string;
  apiSource: string;
  rawDetails: Record<string, unknown>;
  timestamp?: { seconds?: number } | string | null;
}

function RechargeWebPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const urlUid = searchParams.get("uid");

  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
  const [loadingAuth, setLoadingAuth] = useState(true);

  // Auth Modal State
  const [isAuthOpen, setIsAuthOpen] = useState(false);
  const [authError, setAuthError] = useState<string | null>(null);
  const [authSubmitting, setAuthSubmitting] = useState(false);

  // Tab State: "packs" | "search" | "history" | "searches"
  const [activeTab, setActiveTab] = useState<"packs" | "search" | "history" | "searches">("packs");
  const [selectedPack, setSelectedPack] = useState<number>(5);

  // Number Lookup State
  const [searchPhone, setSearchPhone] = useState("");
  const [searching, setSearching] = useState(false);
  const [lookupError, setLookupError] = useState<string | null>(null);
  const [lookupResult, setLookupResult] = useState<SearchRecord | null>(null);
  const [showRawJson, setShowRawJson] = useState(false);
  const [copiedJson, setCopiedJson] = useState(false);

  // Search History State
  const [searchesHistory, setSearchesHistory] = useState<SearchRecord[]>([]);

  // Payment Execution State
  const [processingPayment, setProcessingPayment] = useState(false);
  const [activePayingPack, setActivePayingPack] = useState<number | null>(null);

  // Verification & Pending Order Notice State
  const [verifyingReturn, setVerifyingReturn] = useState(false);
  const [pendingOrderInfo, setPendingOrderInfo] = useState<{
    orderId: string;
    credits: number;
    amount: number;
  } | null>(null);
  const [successNotice, setSuccessNotice] = useState<{
    show: boolean;
    credits: number;
    amount: number;
    orderId: string;
  } | null>(null);
  const [errorNotice, setErrorNotice] = useState<string | null>(null);

  // Orders History State
  const [ordersHistory, setOrdersHistory] = useState<OrderRecord[]>([]);

  // App Download Popup Modal State (Auto pop up on landing)
  const [showAppDownloadModal, setShowAppDownloadModal] = useState(true);

  // Dynamic Pricing Config State (Default ₹40 / credit)
  const [pricePerCredit, setPricePerCredit] = useState<number>(40);
  const [customPacks, setCustomPacks] = useState<CreditPackPlan[]>([]);

  // Prevent multiple auto-verification calls on page refresh
  const verificationProcessedRef = useRef(false);

  // Realtime Pricing Settings Listener from Firestore
  useEffect(() => {
    const pricingRef = doc(db, "settings", "pricing");
    const unsubscribe = onSnapshot(pricingRef, (docSnap) => {
      if (docSnap.exists()) {
        const rate = docSnap.data().pricePerCredit;
        if (typeof rate === "number" && rate > 0) {
          setPricePerCredit(rate);
        }
      }
    });
    return () => unsubscribe();
  }, []);

  // Realtime Packages Stream Listener from Firestore
  useEffect(() => {
    const packsQuery = query(collection(db, "packages"));
    const unsubscribe = onSnapshot(
      packsQuery,
      (snapshot) => {
        const list: CreditPackPlan[] = snapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          ...(docSnap.data() as Omit<CreditPackPlan, "id">),
        }));
        list.sort((a, b) => a.credits - b.credits);
        setCustomPacks(list);
      },
      (err) => console.error("Packages stream error:", err)
    );
    return () => unsubscribe();
  }, []);

  // 1. Firebase Auth Auto-Fetch Listener
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setCurrentUser(user);
      setLoadingAuth(false);

      if (user) {
        // Auto redirect Admin email to /admin
        if (user.email?.toLowerCase() === "akashkapri12109@gmail.com") {
          router.push("/admin");
        }

        // Auto create profile document if not exists
        const userRef = doc(db, "users", user.uid);
        const docSnap = await getDoc(userRef);

        if (!docSnap.exists()) {
          await setDoc(userRef, {
            uid: user.uid,
            email: user.email || "",
            displayName: user.displayName || name || "InfoApp User",
            credits: 1, // 1 Free Welcome Credit
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          });
        }
      } else {
        setUserProfile(null);
      }
    });

    return () => unsubscribe();
  }, [router]);

  // 2. Realtime Profile, Order History & Searches Stream from Firestore
  useEffect(() => {
    const activeUid = currentUser?.uid || urlUid;
    if (!activeUid) return;

    const userRef = doc(db, "users", activeUid);
    const unsubscribeProfile = onSnapshot(userRef, (snapshot) => {
      if (snapshot.exists()) {
        const data = snapshot.data();
        setUserProfile({
          uid: activeUid,
          email: data.email || currentUser?.email || "",
          displayName: data.displayName || "Subscriber",
          credits: data.credits ?? 0,
          customPricePerCredit: data.customPricePerCredit ?? undefined,
        });
      }
    });

    // Stream Order History
    const ordersQuery = query(
      collection(db, "orders"),
      where("userId", "==", activeUid)
    );
    const unsubscribeOrders = onSnapshot(ordersQuery, (snapshot) => {
      const records: OrderRecord[] = snapshot.docs.map((docSnap) => ({
        id: docSnap.id,
        ...(docSnap.data() as Omit<OrderRecord, "id">),
      }));
      // Sort newest first
      records.sort((a, b) => {
        const tA = a.timestamp?.seconds || 0;
        const tB = b.timestamp?.seconds || 0;
        return tB - tA;
      });
      setOrdersHistory(records);
    });

    // Stream Root Lookups Collection (saved by Mobile App)
    const lookupsQuery = query(
      collection(db, "lookups"),
      where("userId", "==", activeUid)
    );

    let mobileLookups: SearchRecord[] = [];
    let webSearches: SearchRecord[] = [];

    const updateCombinedSearches = () => {
      const combinedMap = new Map<string, SearchRecord>();

      [...mobileLookups, ...webSearches].forEach((item) => {
        const key = item.id || `${item.phoneNumber}_${item.name}`;
        if (!combinedMap.has(key)) {
          combinedMap.set(key, item);
        }
      });

      const combinedList = Array.from(combinedMap.values());
      combinedList.sort((a, b) => {
        const tA =
          typeof a.timestamp === "object" && a.timestamp?.seconds
            ? a.timestamp.seconds
            : typeof a.timestamp === "string"
            ? new Date(a.timestamp).getTime() / 1000
            : 0;
        const tB =
          typeof b.timestamp === "object" && b.timestamp?.seconds
            ? b.timestamp.seconds
            : typeof b.timestamp === "string"
            ? new Date(b.timestamp).getTime() / 1000
            : 0;
        return tB - tA;
      });

      setSearchesHistory(combinedList);
    };

    const unsubscribeLookups = onSnapshot(lookupsQuery, (snapshot) => {
      mobileLookups = snapshot.docs.map((docSnap) => {
        const data = docSnap.data();
        const res = data.result || {};
        return {
          id: docSnap.id,
          phoneNumber: data.phoneNumber || res.phoneNumber || "",
          name: res.name || data.name || "Subscriber Details Found",
          carrier: res.carrier || data.carrier || "GSM",
          circle: res.circle || data.circle || "India",
          country: res.country || "India",
          lineType: res.lineType || "Mobile",
          email: res.email || "N/A",
          address: res.address || "N/A",
          apiSource: res.apiSource || "Mobile App Engine",
          rawDetails: res.rawDetails || res,
          timestamp: data.timestamp || res.timestamp,
        };
      });
      updateCombinedSearches();
    });

    // Stream Web Searches History
    const searchesQuery = collection(db, "users", activeUid, "searches");
    const unsubscribeSearches = onSnapshot(searchesQuery, (snapshot) => {
      webSearches = snapshot.docs.map((docSnap) => ({
        id: docSnap.id,
        ...(docSnap.data() as Omit<SearchRecord, "id">),
      }));
      updateCombinedSearches();
    });

    return () => {
      unsubscribeProfile();
      unsubscribeOrders();
      unsubscribeLookups();
      unsubscribeSearches();
    };
  }, [currentUser, urlUid]);

  // Number Lookup Handler
  const handleLookupSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!currentUser) {
      setIsAuthOpen(true);
      return;
    }

    const cleanedNumber = searchPhone.replace(/[^0-9]/g, "");
    if (cleanedNumber.length < 10) {
      setLookupError("Please enter a valid 10-digit mobile number.");
      return;
    }

    if ((userProfile?.credits ?? 0) < 1) {
      setLookupError("Insufficient Credits (Cost: 1 Credit). Please purchase credits below to search.");
      return;
    }

    setSearching(true);
    setLookupError(null);
    setLookupResult(null);

    try {
      const res = await fetch("/api/lookup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          phoneNumber: cleanedNumber,
          uid: currentUser.uid,
        }),
      });

      const data = await res.json();

      if (data.success && data.result) {
        setLookupResult(data.result);
      } else {
        setLookupError(data.error || "Failed to find subscriber details.");
      }
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Lookup error:", error);
      setLookupError(error.message || "Error connecting to lookup server.");
    } finally {
      setSearching(false);
    }
  };

  // Core Verification Routine
  const executeOrderVerification = async (
    orderIdVal: string,
    creditsVal: number,
    amountVal: number
  ) => {
    if (!currentUser) return;
    setVerifyingReturn(true);
    setErrorNotice(null);

    try {
      // Check if order was already fulfilled in Firestore to prevent duplicate credit
      const orderRef = doc(db, "orders", orderIdVal);
      const orderSnap = await getDoc(orderRef);

      if (orderSnap.exists() && orderSnap.data().status === "SUCCESS") {
        setSuccessNotice({
          show: true,
          credits: creditsVal,
          amount: amountVal,
          orderId: orderIdVal,
        });
        setPendingOrderInfo(null);
        setVerifyingReturn(false);
        return;
      }

      // Verify status with Payflux API
      const res = await fetch("/api/payflux/verify-order", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ orderId: orderIdVal }),
      });

      const data = await res.json();

      if (data.success && data.status === "SUCCESS") {
        // Atomically add credits & record transaction in Firestore
        const userRef = doc(db, "users", currentUser.uid);

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
            userId: currentUser.uid,
            orderId: orderIdVal,
            amount: amountVal,
            creditsAdded: creditsVal,
            status: "SUCCESS",
            paymentGateway: "Payflux",
            timestamp: serverTimestamp(),
          });
        });

        setSuccessNotice({
          show: true,
          credits: creditsVal,
          amount: amountVal,
          orderId: orderIdVal,
        });
        setPendingOrderInfo(null);
      } else {
        // Payment is still PENDING on Payflux
        setPendingOrderInfo({ orderId: orderIdVal, credits: creditsVal, amount: amountVal });
        setErrorNotice(
          "Payment status is currently PENDING on Payflux."
        );
      }
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Verification error:", error);
      setErrorNotice("Error verifying payment: " + (error.message || "Unknown error"));
    } finally {
      setVerifyingReturn(false);
    }
  };

  // 3. AUTO-VERIFY & CREDIT AUTO-FULFILLMENT UPON PAYFLUX REDIRECT RETURN
  useEffect(() => {
    if (typeof window === "undefined" || !currentUser || verificationProcessedRef.current) return;

    const searchParams = new URLSearchParams(window.location.search);
    const isPaymentReturn = searchParams.get("payment_return");
    const returnedOrderId = searchParams.get("orderId");
    const returnedCredits = parseInt(searchParams.get("credits") || "0", 10);
    const returnedAmount = parseFloat(searchParams.get("amount") || "0");

    if (isPaymentReturn && returnedOrderId && returnedCredits > 0) {
      verificationProcessedRef.current = true;
      executeOrderVerification(returnedOrderId, returnedCredits, returnedAmount);
      // Clean up URL query parameters cleanly
      window.history.replaceState({}, "", window.location.pathname);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentUser]);

  // Auth Handlers (Google Sign In Only)
  const handleGoogleSignIn = async () => {
    setAuthError(null);
    setAuthSubmitting(true);
    try {
      const provider = new GoogleAuthProvider();
      const res = await signInWithPopup(auth, provider);
      const user = res.user;

      // Auto create profile document if not exists
      const userRef = doc(db, "users", user.uid);
      const docSnap = await getDoc(userRef);

      if (!docSnap.exists()) {
        await setDoc(userRef, {
          uid: user.uid,
          email: user.email || "",
          displayName: user.displayName || "InfoApp User",
          credits: 1, // 1 Free Welcome Credit
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
      }

      setIsAuthOpen(false);
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Google Auth error:", error);
      let cleanMsg = error.message || "Authentication failed.";
      if (cleanMsg.includes("popup-closed-by-user")) {
        cleanMsg = "Sign in cancelled.";
      }
      setAuthError(cleanMsg);
    } finally {
      setAuthSubmitting(false);
    }
  };

  const handleLogout = async () => {
    await signOut(auth);
  };

  // DIRECT CREDIT RECHARGE WORKFLOW (ZERO PAYMENT GATEWAY)
  const handleInitiateRechargeAndRedirect = async (amount: number, credits: number) => {
    const activeUid = currentUser?.uid || urlUid;
    if (!activeUid) {
      setIsAuthOpen(true);
      return;
    }

    setProcessingPayment(true);
    setActivePayingPack(credits);
    setErrorNotice(null);

    try {
      const directOrderId = `DIRECT_RECHARGE_${Date.now()}`;
      
      // Directly credit user balance in Firestore
      const userRef = doc(db, "users", activeUid);
      const orderRef = doc(db, "orders", directOrderId);

      await runTransaction(db, async (transaction) => {
        const userSnap = await transaction.get(userRef);
        const currentCredits = userSnap.exists()
          ? userSnap.data().credits || 0
          : 0;

        transaction.update(userRef, {
          credits: currentCredits + credits,
          updatedAt: serverTimestamp(),
        });

        transaction.set(orderRef, {
          userId: activeUid,
          orderId: directOrderId,
          amount: amount,
          creditsAdded: credits,
          status: "SUCCESS",
          paymentGateway: "Direct",
          timestamp: serverTimestamp(),
        });
      });

      setSuccessNotice({
        show: true,
        credits: credits,
        amount: amount,
        orderId: directOrderId,
      });
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Direct recharge error:", error);
      setErrorNotice("Error adding credits: " + (error.message || "Unknown error"));
    } finally {
      setProcessingPayment(false);
      setActivePayingPack(null);
    }
  };

  const effectiveRate = userProfile?.customPricePerCredit || pricePerCredit || 40;

  const defaultPacks = [
    { credits: 1, price: effectiveRate * 1, title: "Starter Pack", tag: "", desc: "1 Full Number Search", recommended: false },
    { credits: 3, price: effectiveRate * 3, title: "Value Pack", tag: "Popular", desc: "3 Full Number Searches", recommended: false },
    { credits: 5, price: effectiveRate * 5, title: "Pro Pack", tag: "Best Value", desc: "5 Full Number Searches", recommended: true },
    { credits: 10, price: effectiveRate * 10, title: "Ultra Pack", tag: "20% Extra", desc: "10 Full Number Searches", recommended: false },
  ];

  const creditPacks = customPacks.length > 0
    ? customPacks.map((p) => ({
        credits: p.credits,
        price: userProfile?.customPricePerCredit ? p.credits * userProfile.customPricePerCredit : p.price,
        title: p.title,
        tag: p.tag || "",
        desc: p.desc || `${p.credits} Full Number Searches`,
        recommended: Boolean(p.recommended),
      }))
    : defaultPacks;

  return (
    <main className="min-h-screen bg-[#0B0F17] text-slate-100 flex flex-col font-sans selection:bg-cyan-500 selection:text-black">
      {/* Verification Spinner Banner */}
      {verifyingReturn && (
        <div className="bg-gradient-to-r from-cyan-600 to-blue-600 text-black px-4 py-3 text-center text-xs sm:text-sm font-bold flex items-center justify-center gap-2 animate-pulse shadow-lg">
          <RefreshCw className="h-4 w-4 animate-spin text-black" />
          Verifying your Payflux payment and crediting your account balance... Please hold on!
        </div>
      )}

      {/* Success Celebration Banner / Toast */}
      {successNotice?.show && (
        <div className="bg-gradient-to-r from-emerald-500 via-teal-500 to-cyan-500 text-black px-4 py-4 text-center font-bold flex flex-col sm:flex-row items-center justify-center gap-3 shadow-xl relative z-50">
          <div className="flex items-center gap-2">
            <PartyPopper className="h-6 w-6 text-black" />
            <span className="text-sm sm:text-base">
              Payment Successful! +{successNotice.credits} Credits added to your account balance.
            </span>
          </div>
          <button
            onClick={() => setSuccessNotice(null)}
            className="px-3 py-1 rounded-lg bg-black/20 text-black hover:bg-black/40 text-xs uppercase tracking-wider font-extrabold"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* Pending Order Notice & Manual Re-verify Action */}
      {pendingOrderInfo && (
        <div className="bg-gradient-to-r from-amber-500 to-orange-500 text-black px-4 py-3 text-center text-xs sm:text-sm font-bold flex flex-wrap items-center justify-center gap-3 shadow-lg">
          <div className="flex items-center gap-1.5">
            <Clock className="h-4 w-4 text-black" />
            <span>
              Pending Payflux Order: #{pendingOrderInfo.orderId} (₹{pendingOrderInfo.amount} for +{pendingOrderInfo.credits} Credits)
            </span>
          </div>
          <button
            onClick={() =>
              executeOrderVerification(
                pendingOrderInfo.orderId,
                pendingOrderInfo.credits,
                pendingOrderInfo.amount
              )
            }
            disabled={verifyingReturn}
            className="px-4 py-1.5 rounded-lg bg-black text-white hover:bg-slate-900 text-xs uppercase tracking-wider font-extrabold flex items-center gap-1.5"
          >
            {verifyingReturn ? (
              <RefreshCw className="h-3.5 w-3.5 animate-spin" />
            ) : (
              <CheckCircle2 className="h-3.5 w-3.5" />
            )}
            Verify Payment Now
          </button>
        </div>
      )}

      {/* Error Notice Banner */}
      {errorNotice && !pendingOrderInfo && (
        <div className="bg-rose-500 text-white px-4 py-3 text-center text-xs sm:text-sm font-semibold flex items-center justify-center gap-2 shadow-lg">
          <XCircle className="h-4 w-4" />
          <span>{errorNotice}</span>
          <button
            onClick={() => setErrorNotice(null)}
            className="ml-4 underline text-xs text-white hover:text-slate-200"
          >
            Close
          </button>
        </div>
      )}

      {/* Header Bar */}
      <header className="sticky top-0 z-40 glass-panel border-b border-white/10 px-4 lg:px-8 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="h-10 w-10 rounded-xl bg-gradient-to-tr from-cyan-500 to-purple-600 flex items-center justify-center shadow-lg shadow-cyan-500/20">
            <Zap className="h-6 w-6 text-black fill-black" />
          </div>
          <div>
            <h1 className="font-bold text-lg leading-none tracking-tight">
              InfoApp <span className="text-cyan-400">Credit Portal</span>
            </h1>
            <p className="text-xs text-slate-400 mt-1 flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse"></span>
              Firebase Realtime Balance Sync
            </p>
          </div>
        </div>

        {/* User Account / Auth Widget */}
        <div className="flex items-center gap-3">
          {loadingAuth ? (
            <div className="h-9 w-28 bg-slate-800 animate-pulse rounded-xl"></div>
          ) : currentUser ? (
            <div className="flex items-center gap-3">
              {/* Download App Navigation Button */}
              <button
                onClick={() => setShowAppDownloadModal(true)}
                className="px-3 py-1.5 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-400 text-black text-xs font-extrabold flex items-center gap-1.5 transition shadow-sm hover:opacity-90"
              >
                <Download className="h-4 w-4" />
                <span>Get App</span>
              </button>

              {/* Dashboard Navigation Button */}
              <button
                onClick={() => router.push("/dashboard")}
                className="px-3.5 py-1.5 rounded-xl glass-panel hover:bg-cyan-500/20 border border-cyan-500/40 text-cyan-400 text-xs font-bold flex items-center gap-1.5 transition shadow-sm"
              >
                <LayoutDashboard className="h-4 w-4" />
                <span>Dashboard</span>
              </button>

              {/* Credit Balance Badge */}
              <div className="glass-card px-3.5 py-1.5 rounded-xl flex items-center gap-2 border border-cyan-500/30 shadow-md shadow-cyan-500/10">
                <Sparkles className="h-4 w-4 text-cyan-400 animate-spin-slow" />
                <span className="text-xs text-slate-300">Balance:</span>
                <span className="font-bold text-sm text-cyan-400">
                  {userProfile?.credits ?? 0} Credits
                </span>
              </div>

              {/* User Menu */}
              <div className="hidden sm:flex items-center gap-2 glass-panel px-3 py-1.5 rounded-xl border border-white/5">
                <div className="h-7 w-7 rounded-full bg-purple-500/20 border border-purple-400/40 flex items-center justify-center font-bold text-xs text-purple-300">
                  {userProfile?.displayName?.substring(0, 1).toUpperCase() || "U"}
                </div>
                <span className="text-xs font-medium text-slate-200">
                  {userProfile?.displayName || currentUser.email}
                </span>
              </div>

              <button
                onClick={handleLogout}
                className="p-2 rounded-xl glass-panel hover:bg-rose-500/20 hover:border-rose-500/40 text-slate-400 hover:text-rose-400 transition"
                title="Sign Out"
              >
                <LogOut className="h-4 w-4" />
              </button>
            </div>
          ) : (
            <button
              onClick={() => setIsAuthOpen(true)}
              className="btn-gradient px-4 py-2 rounded-xl text-xs flex items-center gap-1.5"
            >
              <UserIcon className="h-4 w-4" />
              Sign In to Recharge
            </button>
          )}
        </div>
      </header>

      {/* Hero Banner */}
      <section className="px-4 lg:px-8 py-8 max-w-6xl mx-auto w-full">
        <div className="relative overflow-hidden rounded-3xl glass-card p-6 sm:p-10 border border-cyan-500/20">
          <div className="absolute -right-16 -top-16 h-64 w-64 bg-cyan-500/10 rounded-full blur-3xl pointer-events-none"></div>
          <div className="absolute -left-16 -bottom-16 h-64 w-64 bg-purple-500/10 rounded-full blur-3xl pointer-events-none"></div>

          <div className="relative z-10 max-w-2xl">
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold bg-cyan-500/10 text-cyan-400 border border-cyan-500/30 mb-4">
              <Zap className="h-3.5 w-3.5" /> Direct Account Credit Upgrade
            </span>
            <h2 className="text-2xl sm:text-4xl font-extrabold tracking-tight leading-tight">
              Buy Search Credits <span className="text-gradient">For Your InfoApp Account</span>
            </h2>
            <p className="text-slate-400 text-sm sm:text-base mt-3 leading-relaxed">
              Select a credit package below to recharge your account balance instantly. Your credits will automatically sync with your mobile app!
            </p>

            {currentUser && (
              <div className="mt-6 flex flex-wrap items-center gap-4">
                <div className="glass-panel px-4 py-2.5 rounded-2xl border border-cyan-500/40 flex items-center gap-3">
                  <div className="p-2 rounded-xl bg-cyan-500/20 text-cyan-400">
                    <Sparkles className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="text-xs text-slate-400">Logged In Account</div>
                    <div className="text-sm font-semibold text-white">
                      {userProfile?.displayName} ({userProfile?.email})
                    </div>
                  </div>
                </div>

                <div className="glass-panel px-4 py-2.5 rounded-2xl border border-purple-500/40 flex items-center gap-3">
                  <div className="p-2 rounded-xl bg-purple-500/20 text-purple-400">
                    <CreditCard className="h-5 w-5" />
                  </div>
                  <div>
                    <div className="text-xs text-slate-400">Available Balance</div>
                    <div className="text-base font-bold text-cyan-400">
                      {userProfile?.credits ?? 0} Credits
                    </div>
                  </div>
                </div>

                {userProfile?.customPricePerCredit && (
                  <div className="glass-panel px-4 py-2.5 rounded-2xl border border-emerald-500/40 flex items-center gap-3 bg-emerald-500/10">
                    <div className="p-2 rounded-xl bg-emerald-500/20 text-emerald-400">
                      <Zap className="h-5 w-5" />
                    </div>
                    <div>
                      <div className="text-xs text-emerald-300 font-bold">Special Rate Assigned</div>
                      <div className="text-sm font-extrabold text-emerald-400">
                        ₹{userProfile.customPricePerCredit} / Credit
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Tab Navigation */}
        <div className="mt-8 flex border-b border-white/10 gap-6 overflow-x-auto pb-1">
          <button
            onClick={() => setActiveTab("packs")}
            className={`pb-3 text-sm sm:text-base font-semibold flex items-center gap-2 transition border-b-2 whitespace-nowrap px-1 ${
              activeTab === "packs"
                ? "border-cyan-400 text-cyan-400"
                : "border-transparent text-slate-400 hover:text-slate-200"
            }`}
          >
            <Zap className="h-4 w-4" /> Credit Packages
          </button>

          <button
            onClick={() => setActiveTab("search")}
            className={`pb-3 text-sm sm:text-base font-semibold flex items-center gap-2 transition border-b-2 whitespace-nowrap px-1 ${
              activeTab === "search"
                ? "border-cyan-400 text-cyan-400"
                : "border-transparent text-slate-400 hover:text-slate-200"
            }`}
          >
            <Search className="h-4 w-4" /> Number Lookup
          </button>

          <button
            onClick={() => setActiveTab("history")}
            className={`pb-3 text-sm sm:text-base font-semibold flex items-center gap-2 transition border-b-2 whitespace-nowrap px-1 ${
              activeTab === "history"
                ? "border-cyan-400 text-cyan-400"
                : "border-transparent text-slate-400 hover:text-slate-200"
            }`}
          >
            <History className="h-4 w-4" /> Order History
          </button>

          <button
            onClick={() => setActiveTab("searches")}
            className={`pb-3 text-sm sm:text-base font-semibold flex items-center gap-2 transition border-b-2 whitespace-nowrap px-1 ${
              activeTab === "searches"
                ? "border-cyan-400 text-cyan-400"
                : "border-transparent text-slate-400 hover:text-slate-200"
            }`}
          >
            <Phone className="h-4 w-4" /> Search History
          </button>
        </div>

        {/* TAB 0: NUMBER LOOKUP INTELLIGENCE */}
        {activeTab === "search" && (
          <div className="mt-8 space-y-6">
            {/* Search Input Card */}
            <div className="glass-card rounded-2xl p-6 border border-cyan-500/30">
              <h3 className="text-xl font-bold text-white mb-1 flex items-center gap-2">
                <Search className="h-5 w-5 text-cyan-400" />
                Mobile Number Intelligence Lookup
              </h3>
              <p className="text-xs text-slate-400 mb-6">
                Cost: <span className="text-cyan-400 font-bold">1 Credit</span> per successful lookup • Multi-API Engine with real-time fallback
              </p>

              {lookupError && (
                <div className="mb-4 p-3.5 rounded-xl bg-rose-500/20 text-rose-300 border border-rose-500/30 text-xs flex items-center gap-2">
                  <ShieldAlert className="h-4 w-4 text-rose-400 flex-shrink-0" />
                  <span>{lookupError}</span>
                </div>
              )}

              <form onSubmit={handleLookupSubmit} className="space-y-4">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-2">
                    Enter 10-Digit Mobile Number
                  </label>
                  <div className="relative">
                    <Phone className="absolute left-4 top-3.5 h-5 w-5 text-cyan-400" />
                    <input
                      type="tel"
                      maxLength={10}
                      required
                      value={searchPhone}
                      onChange={(e) => setSearchPhone(e.target.value)}
                      placeholder="e.g. 9876543210"
                      className="w-full pl-12 pr-4 py-3 rounded-xl bg-slate-900 border border-white/10 text-white font-mono text-lg tracking-wider focus:outline-none focus:border-cyan-400"
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  disabled={searching}
                  className="w-full py-3.5 rounded-xl btn-gradient text-xs uppercase tracking-wider font-extrabold flex items-center justify-center gap-2 shadow-lg shadow-cyan-500/20 disabled:opacity-50"
                >
                  {searching ? (
                    <>
                      <RefreshCw className="h-4 w-4 animate-spin text-black" />
                      Searching Multi-API Servers...
                    </>
                  ) : (
                    <>
                      <Search className="h-4 w-4 text-black fill-black" />
                      LOOKUP NUMBER DETAILS (1 CREDIT)
                    </>
                  )}
                </button>
              </form>
            </div>

            {/* Lookup Result Modal / Card */}
            {lookupResult && (
              <div className="glass-card rounded-2xl p-6 border border-emerald-500/40 relative overflow-hidden animate-fadeIn">
                <div className="flex flex-wrap items-center justify-between gap-2 border-b border-white/10 pb-4 mb-4">
                  <div className="flex items-center gap-2">
                    <span className="px-3 py-1 rounded-full text-xs font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                      Subscriber Details Found
                    </span>
                    <span className="px-3 py-1 rounded-full text-xs font-mono bg-cyan-500/10 text-cyan-400 border border-cyan-500/20">
                      {lookupResult.apiSource}
                    </span>
                  </div>
                  <span className="text-xs text-slate-400 font-mono">
                    {typeof lookupResult.timestamp === "string"
                      ? new Date(lookupResult.timestamp).toLocaleString()
                      : typeof lookupResult.timestamp === "object" && lookupResult.timestamp?.seconds
                      ? new Date(lookupResult.timestamp.seconds * 1000).toLocaleString()
                      : "Recently"}
                  </span>
                </div>

                {/* Details Grid */}
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                  <div className="glass-panel p-4 rounded-xl border border-white/5">
                    <div className="text-[11px] text-slate-400 font-semibold mb-1">Subscriber Name</div>
                    <div className="text-lg font-bold text-white flex items-center gap-2">
                      <UserIcon className="h-4 w-4 text-cyan-400" />
                      {lookupResult.name}
                    </div>
                  </div>

                  <div className="glass-panel p-4 rounded-xl border border-white/5">
                    <div className="text-[11px] text-slate-400 font-semibold mb-1">Mobile Number & Line</div>
                    <div className="text-base font-bold text-cyan-400 font-mono flex items-center gap-2">
                      <Phone className="h-4 w-4 text-cyan-400" />
                      +91 {lookupResult.phoneNumber} ({lookupResult.lineType})
                    </div>
                  </div>

                  <div className="glass-panel p-4 rounded-xl border border-white/5">
                    <div className="text-[11px] text-slate-400 font-semibold mb-1">Carrier & Circle</div>
                    <div className="text-base font-bold text-purple-300">
                      {lookupResult.carrier} • {lookupResult.circle}
                    </div>
                  </div>

                  <div className="glass-panel p-4 rounded-xl border border-white/5">
                    <div className="text-[11px] text-slate-400 font-semibold mb-1">Email Address</div>
                    <div className="text-xs font-semibold text-slate-200 truncate flex items-center gap-1.5">
                      <Mail className="h-3.5 w-3.5 text-slate-400" />
                      {lookupResult.email}
                    </div>
                  </div>

                  <div className="glass-panel p-4 rounded-xl border border-white/5 sm:col-span-2">
                    <div className="text-[11px] text-slate-400 font-semibold mb-1">Registered Address</div>
                    <div className="text-xs font-semibold text-slate-200 flex items-center gap-1.5">
                      <MapPin className="h-3.5 w-3.5 text-slate-400" />
                      {lookupResult.address}
                    </div>
                  </div>
                </div>

                {/* Raw Details Accordion */}
                <div className="mt-4 pt-4 border-t border-white/10">
                  <div className="flex items-center justify-between">
                    <button
                      onClick={() => setShowRawJson(!showRawJson)}
                      className="text-xs font-bold text-cyan-400 underline hover:text-cyan-300"
                    >
                      {showRawJson ? "Hide Full Raw Intelligence Data" : "View Full Raw Intelligence Data"}
                    </button>

                    {showRawJson && (
                      <button
                        onClick={() => {
                          navigator.clipboard.writeText(JSON.stringify(lookupResult.rawDetails, null, 2));
                          setCopiedJson(true);
                          setTimeout(() => setCopiedJson(false), 2000);
                        }}
                        className="px-3 py-1 rounded-lg glass-panel hover:bg-slate-800 text-xs text-slate-300 font-semibold flex items-center gap-1.5"
                      >
                        {copiedJson ? (
                          <>
                            <Check className="h-3.5 w-3.5 text-emerald-400" /> Copied!
                          </>
                        ) : (
                          <>
                            <Copy className="h-3.5 w-3.5" /> Copy JSON
                          </>
                        )}
                      </button>
                    )}
                  </div>

                  {showRawJson && (
                    <pre className="mt-3 p-4 rounded-xl bg-slate-900 border border-white/10 text-[11px] font-mono text-cyan-300 overflow-x-auto max-h-60 leading-relaxed">
                      {JSON.stringify(lookupResult.rawDetails, null, 2)}
                    </pre>
                  )}
                </div>
              </div>
            )}
          </div>
        )}

        {/* TAB 1: CREDIT PACKS */}
        {activeTab === "packs" && (
          <div className="mt-8 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
            {creditPacks.map((pack) => {
              const isSelected = selectedPack === pack.credits;
              const isThisPackPaying = processingPayment && activePayingPack === pack.credits;

              return (
                <div
                  key={pack.credits}
                  onClick={() => setSelectedPack(pack.credits)}
                  className={`cursor-pointer rounded-2xl glass-card p-6 border transition-all duration-300 relative flex flex-col justify-between ${
                    isSelected
                      ? "border-cyan-400 ring-2 ring-cyan-400/30 scale-[1.02] shadow-xl shadow-cyan-500/10"
                      : "border-white/10 hover:border-cyan-500/40"
                  }`}
                >
                  {pack.tag && (
                    <span className="absolute -top-3 right-4 px-3 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-gradient-to-r from-purple-600 to-pink-600 text-white shadow-md">
                      {pack.tag}
                    </span>
                  )}

                  <div>
                    <h3 className="text-lg font-bold text-white">{pack.title}</h3>
                    <div className="mt-4 flex items-baseline gap-1">
                      <span className="text-3xl font-extrabold text-cyan-400">
                        ₹{pack.price}
                      </span>
                      <span className="text-xs text-slate-400">/ one-time</span>
                    </div>

                    <div className="mt-4 pt-4 border-t border-white/10 space-y-2">
                      <div className="flex items-center gap-2 text-xs text-slate-300">
                        <CheckCircle2 className="h-4 w-4 text-cyan-400" />
                        <span className="font-semibold">{pack.credits} Search Credits</span>
                      </div>
                      <div className="flex items-center gap-2 text-xs text-slate-400">
                        <CheckCircle2 className="h-4 w-4 text-cyan-400" />
                        <span>Instant Account Auto-Sync</span>
                      </div>
                      <div className="flex items-center gap-2 text-xs text-slate-400">
                        <CheckCircle2 className="h-4 w-4 text-cyan-400" />
                        <span>Payflux UPI Secured</span>
                      </div>
                    </div>
                  </div>

                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      handleInitiateRechargeAndRedirect(pack.price, pack.credits);
                    }}
                    disabled={processingPayment}
                    className="mt-6 w-full py-3.5 rounded-xl btn-gradient text-xs uppercase tracking-wider font-extrabold flex items-center justify-center gap-2 disabled:opacity-50 shadow-lg shadow-cyan-500/20"
                  >
                    {isThisPackPaying ? (
                      <>
                        <RefreshCw className="h-4 w-4 animate-spin text-black" />
                        Redirecting to Payflux...
                      </>
                    ) : (
                      <>
                        <Zap className="h-4 w-4 fill-black" /> BUY ₹{pack.price} VIA PAYFLUX
                      </>
                    )}
                  </button>
                </div>
              );
            })}
          </div>
        )}

        {/* TAB 2: ORDER HISTORY */}
        {activeTab === "history" && (
          <div className="mt-8 glass-card rounded-2xl p-6 border border-white/10">
            <h3 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
              <History className="h-5 w-5 text-cyan-400" />
              Recharge & Payment Log
            </h3>

            {!currentUser ? (
              <p className="text-sm text-slate-400">Please sign in to view your payment history.</p>
            ) : ordersHistory.length === 0 ? (
              <p className="text-sm text-slate-400 py-6 text-center">No past transactions found.</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs text-slate-300">
                  <thead className="bg-slate-900/60 uppercase text-slate-400 border-b border-white/10">
                    <tr>
                      <th className="py-3 px-4">Order ID</th>
                      <th className="py-3 px-4">Amount</th>
                      <th className="py-3 px-4">Credits Added</th>
                      <th className="py-3 px-4">Gateway</th>
                      <th className="py-3 px-4">Status</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    {ordersHistory.map((order) => (
                      <tr key={order.id} className="hover:bg-slate-800/40">
                        <td className="py-3.5 px-4 font-mono text-slate-300">{order.orderId}</td>
                        <td className="py-3.5 px-4 font-bold text-white">₹{order.amount}</td>
                        <td className="py-3.5 px-4 text-cyan-400 font-semibold">
                          +{order.creditsAdded} Credits
                        </td>
                        <td className="py-3.5 px-4">Payflux Gateway</td>
                        <td className="py-3.5 px-4">
                          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                            <CheckCircle2 className="h-3 w-3" /> {order.status}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}

        {/* TAB 3: SEARCH HISTORY */}
        {activeTab === "searches" && (
          <div className="mt-8 glass-card rounded-2xl p-6 border border-white/10">
            <h3 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
              <Phone className="h-5 w-5 text-cyan-400" />
              Number Lookup History Log
            </h3>

            {!currentUser ? (
              <p className="text-sm text-slate-400">Please sign in to view your search history.</p>
            ) : searchesHistory.length === 0 ? (
              <p className="text-sm text-slate-400 py-6 text-center">No past number searches found.</p>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left text-xs text-slate-300">
                  <thead className="bg-slate-900/60 uppercase text-slate-400 border-b border-white/10">
                    <tr>
                      <th className="py-3 px-4">Phone Number</th>
                      <th className="py-3 px-4">Subscriber Name</th>
                      <th className="py-3 px-4">Carrier & Circle</th>
                      <th className="py-3 px-4">Engine Source</th>
                      <th className="py-3 px-4">Date / Time</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-white/5">
                    {searchesHistory.map((search) => (
                      <tr key={search.id} className="hover:bg-slate-800/40">
                        <td className="py-3.5 px-4 font-mono font-bold text-cyan-400">
                          +91 {search.phoneNumber}
                        </td>
                        <td className="py-3.5 px-4 font-semibold text-white">
                          {search.name}
                        </td>
                        <td className="py-3.5 px-4 text-purple-300">
                          {search.carrier} ({search.circle})
                        </td>
                        <td className="py-3.5 px-4 text-slate-400 font-mono text-[11px]">
                          {search.apiSource}
                        </td>
                        <td className="py-3.5 px-4 text-slate-400 font-mono">
                          {typeof search.timestamp === "object" && search.timestamp?.seconds
                            ? new Date(search.timestamp.seconds * 1000).toLocaleString()
                            : typeof search.timestamp === "string"
                            ? new Date(search.timestamp).toLocaleString()
                            : "Recently"}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        )}
      </section>

      {/* Auth Modal */}
      {isAuthOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md">
          <div className="glass-card w-full max-w-md rounded-3xl p-6 border border-white/10 relative text-center">
            <button
              onClick={() => setIsAuthOpen(false)}
              className="absolute top-4 right-4 p-2 rounded-xl bg-slate-800 text-slate-400 hover:text-white"
            >
              <XCircle className="h-5 w-5" />
            </button>

            <div className="h-14 w-14 mx-auto rounded-2xl bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center shadow-lg shadow-cyan-500/20 text-white mb-4">
              <Sparkles className="h-7 w-7" />
            </div>

            <h3 className="text-xl font-bold text-white">
              Sign In to InfoApp
            </h3>
            <p className="text-xs text-slate-400 mt-1">
              Sync your credit balance across Web & Mobile apps with your Google Account
            </p>

            {authError && (
              <div className="mt-4 p-3 rounded-xl bg-rose-500/20 text-rose-300 border border-rose-500/30 text-xs text-center">
                {authError}
              </div>
            )}

            <div className="mt-6">
              <button
                type="button"
                onClick={handleGoogleSignIn}
                disabled={authSubmitting}
                className="w-full py-3.5 px-4 rounded-2xl bg-white hover:bg-slate-100 text-slate-900 font-bold text-sm shadow-xl flex items-center justify-center gap-3 transition-all transform hover:scale-[1.02] active:scale-[0.98] disabled:opacity-50"
              >
                {authSubmitting ? (
                  <RefreshCw className="h-5 w-5 animate-spin text-slate-700" />
                ) : (
                  <>
                    <svg className="h-5 w-5" viewBox="0 0 24 24">
                      <path
                        fill="#4285F4"
                        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                      />
                      <path
                        fill="#34A853"
                        d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                      />
                      <path
                        fill="#FBBC05"
                        d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
                      />
                      <path
                        fill="#EA4335"
                        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
                      />
                    </svg>
                    <span>Sign In with Google</span>
                  </>
                )}
              </button>
            </div>

            <p className="mt-4 text-[11px] text-slate-500">
              🔒 Single Sign-On securely powered by Google Firebase
            </p>
          </div>
        </div>
      )}
      {/* DOWNLOAD MOBILE APP POPUP MODAL */}
      {showAppDownloadModal && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-md flex items-center justify-center p-4 animate-fade-in">
          <div className="glass-card max-w-md w-full p-6 sm:p-8 rounded-3xl border border-cyan-500/40 text-center space-y-5 shadow-2xl relative overflow-hidden">
            <div className="absolute -right-16 -top-16 h-40 w-40 bg-cyan-500/20 rounded-full blur-3xl pointer-events-none"></div>
            <div className="absolute -left-16 -bottom-16 h-40 w-40 bg-purple-500/20 rounded-full blur-3xl pointer-events-none"></div>

            <button
              onClick={() => setShowAppDownloadModal(false)}
              className="absolute top-4 right-4 p-2 rounded-full glass-panel hover:bg-slate-800 text-slate-400 hover:text-white transition"
              title="Close"
            >
              <X className="h-5 w-5" />
            </button>

            <div className="h-16 w-16 mx-auto rounded-2xl bg-gradient-to-tr from-cyan-500 via-teal-400 to-purple-600 flex items-center justify-center shadow-xl shadow-cyan-500/30 text-black">
              <Smartphone className="h-8 w-8 text-black" />
            </div>

            <div>
              <span className="inline-flex items-center gap-1 px-3 py-0.5 rounded-full text-[11px] font-bold bg-cyan-500/20 text-cyan-400 border border-cyan-500/30 mb-2">
                ⚡ Official Android Mobile App
              </span>
              <h3 className="text-xl sm:text-2xl font-extrabold text-white">
                Download NumInfo App
              </h3>
              <p className="text-xs sm:text-sm text-slate-300 mt-2 leading-relaxed">
                Get instant mobile number searches, live search history, and automatic credit balance sync directly on your Android device!
              </p>
            </div>

            <div className="pt-2 space-y-3">
              <a
                href="https://raw.githubusercontent.com/akmtechofficial/info-App/refs/heads/main/app-armeabi-v7a-release.apk"
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => setShowAppDownloadModal(false)}
                className="w-full py-3.5 px-6 rounded-2xl bg-gradient-to-r from-cyan-500 via-teal-400 to-emerald-400 text-black font-extrabold text-xs sm:text-sm uppercase tracking-wider hover:opacity-90 transition shadow-xl shadow-cyan-500/25 flex items-center justify-center gap-2"
              >
                <Download className="h-5 w-5" /> Download App (.APK)
              </a>

              <button
                onClick={() => setShowAppDownloadModal(false)}
                className="w-full py-2.5 text-xs text-slate-400 hover:text-slate-200 transition font-medium"
              >
                Continue on Web Portal
              </button>
            </div>
          </div>
        </div>
      )}
    </main>
  );
}

export default function RechargeWebPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-[#0B0F17] flex items-center justify-center text-cyan-400 font-bold text-sm">
          Loading Credit Portal...
        </div>
      }
    >
      <RechargeWebPageContent />
    </Suspense>
  );
}
