"use client";

import { useEffect, useState, Suspense } from "react";
import { useRouter } from "next/navigation";
import {
  onAuthStateChanged,
  GoogleAuthProvider,
  signInWithPopup,
  signOut,
  User,
} from "firebase/auth";
import {
  collection,
  doc,
  onSnapshot,
  setDoc,
  deleteDoc,
  serverTimestamp,
  query,
  runTransaction,
} from "firebase/firestore";
import { auth, db } from "@/lib/firebase";
import {
  ShieldCheck,
  Users,
  DollarSign,
  Search,
  PlusCircle,
  ArrowLeft,
  RefreshCw,
  Sparkles,
  Lock,
  Save,
  CheckCircle2,
  AlertCircle,
  History,
  TrendingUp,
  LogOut,
  Package,
  Trash2,
  Edit3,
  Plus,
  Star,
} from "lucide-react";

interface UserRecord {
  uid: string;
  email: string;
  displayName: string;
  credits: number;
  customPricePerCredit?: number | null;
  createdAt?: { seconds?: number } | null;
  updatedAt?: { seconds?: number } | null;
}

interface PricingSettings {
  pricePerCredit: number;
  updatedAt?: { seconds?: number } | null;
}

interface GlobalOrderRecord {
  id: string;
  userId: string;
  orderId: string;
  amount: number;
  creditsAdded: number;
  status: string;
  paymentGateway?: string;
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

function AdminPageContent() {
  const router = useRouter();

  // Firebase Auth & Admin Verification State
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [isAdminAuthenticated, setIsAdminAuthenticated] = useState(false);
  const [loadingAuth, setLoadingAuth] = useState(true);

  // Admin Login Form State
  const [authError, setAuthError] = useState<string | null>(null);
  const [authSubmitting, setAuthSubmitting] = useState(false);

  // Realtime Data
  const [usersList, setUsersList] = useState<UserRecord[]>([]);
  const [globalOrders, setGlobalOrders] = useState<GlobalOrderRecord[]>([]);
  const [pricingSettings, setPricingSettings] = useState<PricingSettings>({
    pricePerCredit: 40,
  });
  const [customPacks, setCustomPacks] = useState<CreditPackPlan[]>([]);

  // Package Management Form State
  const [isPackModalOpen, setIsPackModalOpen] = useState(false);
  const [editingPack, setEditingPack] = useState<CreditPackPlan | null>(null);
  const [packTitle, setPackTitle] = useState("");
  const [packCredits, setPackCredits] = useState<number>(5);
  const [packPrice, setPackPrice] = useState<number>(200);
  const [packTag, setPackTag] = useState("");
  const [packDesc, setPackDesc] = useState("");
  const [packRecommended, setPackRecommended] = useState(false);
  const [savingPack, setSavingPack] = useState(false);

  // UI & Form State
  const [userSearchQuery, setUserSearchQuery] = useState("");
  const [editingPrice, setEditingPrice] = useState<number>(40);
  const [savingPrice, setSavingPrice] = useState(false);
  const [priceSuccessMsg, setPriceSuccessMsg] = useState<string | null>(null);

  // Modal / Credit & Rate Adjust State
  const [selectedUser, setSelectedUser] = useState<UserRecord | null>(null);
  const [creditAmountInput, setCreditAmountInput] = useState<number>(10);
  const [customUserRateInput, setCustomUserRateInput] = useState<string>("");
  const [updatingCredits, setUpdatingCredits] = useState(false);
  const [actionSuccessMsg, setActionSuccessMsg] = useState<string | null>(null);

  const ADMIN_EMAIL = "akashkapri12109@gmail.com";

  // 1. Firebase Auth Listener for Admin Verification (akashkapri12109@gmail.com)
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setCurrentUser(user);
      setLoadingAuth(false);

      if (user && user.email?.toLowerCase() === ADMIN_EMAIL) {
        setIsAdminAuthenticated(true);
        setAuthError(null);
      } else {
        setIsAdminAuthenticated(false);
        if (user) {
          setAuthError(`Access Denied: Only ${ADMIN_EMAIL} is authorized to access Admin Control Panel.`);
        }
      }
    });
    return () => unsubscribe();
  }, []);

  // Firebase Admin Google Sign In Handler
  const handleAdminGoogleLogin = async () => {
    setAuthError(null);
    setAuthSubmitting(true);

    try {
      const provider = new GoogleAuthProvider();
      const res = await signInWithPopup(auth, provider);
      const user = res.user;

      if (user.email?.toLowerCase() !== ADMIN_EMAIL) {
        setAuthError(`Access Denied: Only ${ADMIN_EMAIL} is authorized to access Admin Control Panel.`);
        await signOut(auth);
        setIsAdminAuthenticated(false);
      } else {
        setIsAdminAuthenticated(true);
      }
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Admin Google Auth error:", error);
      let cleanMsg = error.message || "Authentication failed.";
      if (cleanMsg.includes("popup-closed-by-user")) {
        cleanMsg = "Sign in cancelled.";
      }
      setAuthError(cleanMsg);
    } finally {
      setAuthSubmitting(false);
    }
  };

  const handleAdminLogout = async () => {
    await signOut(auth);
    setIsAdminAuthenticated(false);
  };

  // 2. Realtime Stream Users, Pricing & Orders
  useEffect(() => {
    if (!isAdminAuthenticated) return;

    // Stream Users Collection
    const usersQuery = query(collection(db, "users"));
    const unsubscribeUsers = onSnapshot(
      usersQuery,
      (snapshot) => {
        const list: UserRecord[] = snapshot.docs.map((docSnap) => ({
          uid: docSnap.id,
          ...(docSnap.data() as Omit<UserRecord, "uid">),
        }));
        setUsersList(list);
      },
      (err) => console.error("Admin users stream error:", err)
    );

    // Stream Pricing Settings Document
    const pricingRef = doc(db, "settings", "pricing");
    const unsubscribePricing = onSnapshot(
      pricingRef,
      (docSnap) => {
        if (docSnap.exists()) {
          const data = docSnap.data();
          const rate = data.pricePerCredit ?? 40;
          setPricingSettings({
            pricePerCredit: rate,
            updatedAt: data.updatedAt,
          });
          setEditingPrice(rate);
        } else {
          // Initialize default pricing if not present
          setDoc(pricingRef, {
            pricePerCredit: 40,
            updatedAt: serverTimestamp(),
          });
        }
      },
      (err) => console.error("Pricing settings stream error:", err)
    );

    // Stream All Global Orders
    const ordersQuery = query(collection(db, "orders"));
    const unsubscribeOrders = onSnapshot(
      ordersQuery,
      (snapshot) => {
        const list: GlobalOrderRecord[] = snapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          ...(docSnap.data() as Omit<GlobalOrderRecord, "id">),
        }));
        // Sort newest first
        list.sort((a, b) => (b.timestamp?.seconds || 0) - (a.timestamp?.seconds || 0));
        setGlobalOrders(list);
      },
      (err) => console.error("Global orders stream error:", err)
    );

    // Stream Packages Collection
    const packsQuery = query(collection(db, "packages"));
    const unsubscribePacks = onSnapshot(
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

    return () => {
      unsubscribeUsers();
      unsubscribePricing();
      unsubscribeOrders();
      unsubscribePacks();
    };
  }, [isAdminAuthenticated]);

  // Package Management Handlers
  const handleOpenCreatePackModal = () => {
    setEditingPack(null);
    setPackTitle("");
    setPackCredits(5);
    setPackPrice(200);
    setPackTag("");
    setPackDesc("");
    setPackRecommended(false);
    setIsPackModalOpen(true);
  };

  const handleOpenEditPackModal = (pack: CreditPackPlan) => {
    setEditingPack(pack);
    setPackTitle(pack.title);
    setPackCredits(pack.credits);
    setPackPrice(pack.price);
    setPackTag(pack.tag || "");
    setPackDesc(pack.desc || "");
    setPackRecommended(Boolean(pack.recommended));
    setIsPackModalOpen(true);
  };

  const handleSavePack = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!packTitle.trim() || packCredits <= 0 || packPrice <= 0) {
      alert("Please enter a valid plan title, credits (>0) and price (>0).");
      return;
    }

    setSavingPack(true);
    try {
      const packId = editingPack?.id || `pack_${Date.now()}`;
      const packRef = doc(db, "packages", packId);

      await setDoc(
        packRef,
        {
          title: packTitle.trim(),
          credits: Number(packCredits),
          price: Number(packPrice),
          tag: packTag.trim(),
          desc: packDesc.trim() || `${packCredits} Full Number Lookups`,
          recommended: Boolean(packRecommended),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );

      setActionSuccessMsg(`Credit Package "${packTitle}" saved successfully!`);
      setTimeout(() => setActionSuccessMsg(null), 4000);
      setIsPackModalOpen(false);
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Save pack error:", error);
      alert("Failed to save package: " + error.message);
    } finally {
      setSavingPack(false);
    }
  };

  const handleDeletePack = async (packId: string, title: string) => {
    if (!confirm(`Are you sure you want to delete package "${title}"?`)) return;

    try {
      await deleteDoc(doc(db, "packages", packId));
      setActionSuccessMsg(`Package "${title}" deleted successfully!`);
      setTimeout(() => setActionSuccessMsg(null), 4000);
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Delete pack error:", error);
      alert("Failed to delete package: " + error.message);
    }
  };

  const handleSeedDefaultPacks = async () => {
    const defaultPacks = [
      { id: "pack_1", title: "Starter Pack", credits: 1, price: 40, tag: "", desc: "1 Full Number Search", recommended: false },
      { id: "pack_3", title: "Value Pack", credits: 3, price: 120, tag: "Popular", desc: "3 Full Number Searches", recommended: false },
      { id: "pack_5", title: "Pro Pack", credits: 5, price: 200, tag: "Best Value", desc: "5 Full Number Searches", recommended: true },
      { id: "pack_10", title: "Ultra Pack", credits: 10, price: 400, tag: "20% Extra", desc: "10 Full Number Searches", recommended: false },
    ];

    try {
      for (const p of defaultPacks) {
        await setDoc(doc(db, "packages", p.id), { ...p, updatedAt: serverTimestamp() }, { merge: true });
      }
      setActionSuccessMsg("Initialized default credit packages!");
      setTimeout(() => setActionSuccessMsg(null), 4000);
    } catch (err: unknown) {
      const error = err as Error;
      alert("Failed to seed default packages: " + error.message);
    }
  };

  // Save Pricing Settings Handler
  const handleSavePricing = async (e: React.FormEvent) => {
    e.preventDefault();
    if (editingPrice <= 0) {
      alert("Please enter a valid positive price per credit.");
      return;
    }

    setSavingPrice(true);
    setPriceSuccessMsg(null);

    try {
      const pricingRef = doc(db, "settings", "pricing");
      await setDoc(
        pricingRef,
        {
          pricePerCredit: Number(editingPrice),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );

      setPriceSuccessMsg(`Price updated successfully to ₹${editingPrice} per credit!`);
      setTimeout(() => setPriceSuccessMsg(null), 4000);
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Save pricing error:", error);
      alert("Failed to save pricing: " + error.message);
    } finally {
      setSavingPrice(false);
    }
  };

  // Direct User Credit Update Handler (Add / Deduct)
  const handleModifyUserCredits = async (
    targetUser: UserRecord,
    amountDelta: number
  ) => {
    setUpdatingCredits(true);
    setActionSuccessMsg(null);

    try {
      const userRef = doc(db, "users", targetUser.uid);

      await runTransaction(db, async (transaction) => {
        const userSnap = await transaction.get(userRef);
        const currentCredits = userSnap.exists()
          ? userSnap.data().credits || 0
          : 0;

        const newCredits = Math.max(0, currentCredits + amountDelta);

        transaction.update(userRef, {
          credits: newCredits,
          updatedAt: serverTimestamp(),
        });
      });

      setActionSuccessMsg(
        `Successfully updated ${targetUser.displayName || targetUser.email}'s balance to ${
          targetUser.credits + amountDelta
        } credits!`
      );
      setTimeout(() => setActionSuccessMsg(null), 4000);
      setSelectedUser(null);
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Modify user credits error:", error);
      alert("Failed to update credits: " + error.message);
    } finally {
      setUpdatingCredits(false);
    }
  };

  // Set or Reset Custom Price per Credit for a Specific User
  const handleSetCustomUserRate = async (
    targetUser: UserRecord,
    newRate: number | null
  ) => {
    setUpdatingCredits(true);
    setActionSuccessMsg(null);

    try {
      const userRef = doc(db, "users", targetUser.uid);
      if (newRate === null || newRate <= 0) {
        await setDoc(
          userRef,
          {
            customPricePerCredit: null,
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        );
        setActionSuccessMsg(
          `Reset ${targetUser.displayName || targetUser.email}'s rate to Global Default (₹${pricingSettings.pricePerCredit}/Credit)!`
        );
      } else {
        await setDoc(
          userRef,
          {
            customPricePerCredit: Number(newRate),
            updatedAt: serverTimestamp(),
          },
          { merge: true }
        );
        setActionSuccessMsg(
          `Set custom rate of ₹${newRate}/Credit for ${targetUser.displayName || targetUser.email}!`
        );
      }

      setTimeout(() => setActionSuccessMsg(null), 4000);
      setSelectedUser(null);
    } catch (err: unknown) {
      const error = err as Error;
      console.error("Set custom user rate error:", error);
      alert("Failed to update user rate: " + error.message);
    } finally {
      setUpdatingCredits(false);
    }
  };

  const formatDate = (seconds?: number) => {
    if (!seconds) return "N/A";
    return new Date(seconds * 1000).toLocaleString();
  };

  // Filtered users list
  const filteredUsers = usersList.filter(
    (u) =>
      (u.email || "").toLowerCase().includes(userSearchQuery.toLowerCase()) ||
      (u.displayName || "").toLowerCase().includes(userSearchQuery.toLowerCase()) ||
      (u.uid || "").toLowerCase().includes(userSearchQuery.toLowerCase())
  );

  // Stats calculation
  const totalRevenue = globalOrders
    .filter((o) => o.status === "SUCCESS")
    .reduce((acc, curr) => acc + (curr.amount || 0), 0);

  const totalCreditsGranted = globalOrders
    .filter((o) => o.status === "SUCCESS")
    .reduce((acc, curr) => acc + (curr.creditsAdded || 0), 0);

  if (loadingAuth) {
    return (
      <main className="min-h-screen bg-[#0B0F17] flex items-center justify-center text-cyan-400">
        <RefreshCw className="h-8 w-8 animate-spin" />
      </main>
    );
  }

  // Security Gate UI (Google Auth restricted to akashkapri12109@gmail.com)
  if (!isAdminAuthenticated) {
    return (
      <main className="min-h-screen bg-[#0B0F17] text-slate-100 flex flex-col items-center justify-center p-4 font-sans">
        <div className="glass-card max-w-md w-full p-8 rounded-3xl border border-cyan-500/30 text-center space-y-6 shadow-2xl relative overflow-hidden">
          <div className="absolute -right-12 -top-12 h-32 w-32 bg-cyan-500/10 rounded-full blur-2xl pointer-events-none"></div>

          <div className="h-16 w-16 mx-auto rounded-2xl bg-gradient-to-tr from-cyan-500 to-purple-600 flex items-center justify-center shadow-lg shadow-cyan-500/20 text-black">
            <Lock className="h-8 w-8 text-black" />
          </div>

          <div>
            <h2 className="text-2xl font-extrabold text-white">Admin Control Panel</h2>
            <p className="text-xs text-slate-400 mt-1">
              Restricted access. Only authorized admin account (<span className="text-cyan-400 font-mono font-bold">akashkapri12109@gmail.com</span>) can log in.
            </p>
          </div>

          {currentUser && currentUser.email?.toLowerCase() !== "akashkapri12109@gmail.com" && (
            <div className="p-3.5 rounded-xl bg-amber-500/20 text-amber-300 border border-amber-500/30 text-xs flex flex-col items-center gap-2">
              <span>Logged in as non-admin: <strong>{currentUser.email}</strong></span>
              <button
                onClick={handleAdminLogout}
                className="px-3.5 py-1.5 rounded-lg bg-amber-500 text-black font-bold text-xs hover:opacity-90"
              >
                Sign Out & Switch Account
              </button>
            </div>
          )}

          {authError && (
            <div className="p-3.5 rounded-xl bg-rose-500/20 text-rose-300 border border-rose-500/30 text-xs flex items-center justify-center gap-2 font-medium">
              <AlertCircle className="h-4 w-4 text-rose-400 flex-shrink-0" />
              <span>{authError}</span>
            </div>
          )}

          <button
            type="button"
            onClick={handleAdminGoogleLogin}
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
                <span>Sign In with Google (Admin)</span>
              </>
            )}
          </button>

          <div className="pt-2">
            <button
              onClick={() => router.push("/")}
              className="text-xs text-slate-400 hover:text-cyan-400 flex items-center justify-center gap-1 mx-auto transition"
            >
              <ArrowLeft className="h-3.5 w-3.5" /> Back to Main Portal
            </button>
          </div>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-[#0B0F17] text-slate-100 flex flex-col font-sans selection:bg-cyan-500 selection:text-black">
      {/* Top Admin Header Bar */}
      <header className="sticky top-0 z-40 glass-panel border-b border-cyan-500/30 px-4 lg:px-8 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button
            onClick={() => router.push("/")}
            className="p-2 rounded-xl glass-panel hover:bg-slate-800 text-slate-400 hover:text-white transition"
            title="Back to Credit Portal"
          >
            <ArrowLeft className="h-5 w-5" />
          </button>
          <div className="h-10 w-10 rounded-xl bg-gradient-to-tr from-cyan-500 to-purple-600 flex items-center justify-center shadow-lg shadow-cyan-500/20">
            <ShieldCheck className="h-6 w-6 text-black" />
          </div>
          <div>
            <h1 className="font-bold text-lg leading-none tracking-tight">
              InfoApp <span className="text-cyan-400">Admin Control Panel</span>
            </h1>
            <p className="text-xs text-slate-400 mt-1 flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse"></span>
              Logged in as: <strong className="text-cyan-400 font-mono">{currentUser?.email || "akashkapri12109@gmail.com"}</strong>
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3">
          <div className="glass-card px-3.5 py-1.5 rounded-xl border border-cyan-500/40 text-xs font-bold text-cyan-400 flex items-center gap-1.5">
            <DollarSign className="h-4 w-4" /> Rate: ₹{pricingSettings.pricePerCredit} / Credit
          </div>
          <button
            onClick={handleAdminLogout}
            className="px-3 py-1.5 rounded-xl bg-rose-500/20 text-rose-300 border border-rose-500/30 hover:bg-rose-500/30 text-xs font-bold flex items-center gap-1.5 transition"
          >
            <LogOut className="h-3.5 w-3.5" /> Sign Out Admin
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <section className="px-4 lg:px-8 py-8 max-w-6xl mx-auto w-full space-y-8 flex-1">
        {/* Toast / Global Success Notification */}
        {actionSuccessMsg && (
          <div className="p-4 rounded-2xl bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 text-sm font-bold flex items-center gap-3 shadow-lg animate-fade-in">
            <CheckCircle2 className="h-5 w-5 text-emerald-400 flex-shrink-0" />
            <span>{actionSuccessMsg}</span>
          </div>
        )}

        {/* Top Overview Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div className="glass-card p-5 rounded-2xl border border-cyan-500/30 flex items-center gap-4">
            <div className="p-3 rounded-xl bg-cyan-500/20 text-cyan-400">
              <Users className="h-6 w-6" />
            </div>
            <div>
              <div className="text-xs text-slate-400 font-semibold">Total Registered Users</div>
              <div className="text-2xl font-extrabold text-white mt-0.5">{usersList.length}</div>
            </div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-emerald-500/30 flex items-center gap-4">
            <div className="p-3 rounded-xl bg-emerald-500/20 text-emerald-400">
              <TrendingUp className="h-6 w-6" />
            </div>
            <div>
              <div className="text-xs text-slate-400 font-semibold">Total Revenue Generated</div>
              <div className="text-2xl font-extrabold text-emerald-400 mt-0.5">₹{totalRevenue}</div>
            </div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-purple-500/30 flex items-center gap-4">
            <div className="p-3 rounded-xl bg-purple-500/20 text-purple-400">
              <Sparkles className="h-6 w-6" />
            </div>
            <div>
              <div className="text-xs text-slate-400 font-semibold">Total Credits Sold</div>
              <div className="text-2xl font-extrabold text-purple-300 mt-0.5">{totalCreditsGranted} Credits</div>
            </div>
          </div>
        </div>

        {/* SECTION 1: GLOBAL PRICING CONFIGURATION */}
        <div className="glass-card rounded-3xl p-6 sm:p-8 border border-cyan-500/30 relative overflow-hidden">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 mb-6">
            <div>
              <h2 className="text-xl font-extrabold text-white flex items-center gap-2">
                <DollarSign className="h-5 w-5 text-cyan-400" />
                Credit Purchase Pricing Config
              </h2>
              <p className="text-xs text-slate-400 mt-1">
                Define how much ₹ (Rupees) a user pays per credit. (Default rate: ₹40 per credit)
              </p>
            </div>

            <div className="glass-panel px-4 py-2 rounded-2xl border border-white/10 text-xs font-mono text-slate-300">
              Current Default: <span className="text-cyan-400 font-bold">₹{pricingSettings.pricePerCredit} / Credit</span>
            </div>
          </div>

          {priceSuccessMsg && (
            <div className="mb-4 p-3 rounded-xl bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 text-xs flex items-center gap-2 font-medium">
              <CheckCircle2 className="h-4 w-4 text-emerald-400" />
              <span>{priceSuccessMsg}</span>
            </div>
          )}

          <form onSubmit={handleSavePricing} className="flex flex-col sm:flex-row items-center gap-4">
            <div className="relative w-full sm:w-72">
              <span className="absolute left-4 top-3 text-sm font-bold text-cyan-400">₹</span>
              <input
                type="number"
                min={1}
                required
                value={editingPrice}
                onChange={(e) => setEditingPrice(Number(e.target.value))}
                placeholder="Enter price in ₹"
                className="w-full pl-8 pr-4 py-2.5 rounded-xl bg-slate-900 border border-white/10 text-white font-bold text-sm focus:outline-none focus:border-cyan-400"
              />
            </div>

            <button
              type="submit"
              disabled={savingPrice}
              className="w-full sm:w-auto px-6 py-2.5 rounded-xl bg-cyan-500 text-black font-extrabold text-xs uppercase tracking-wider hover:bg-cyan-400 transition flex items-center justify-center gap-2 shadow-lg shadow-cyan-500/20"
            >
              {savingPrice ? (
                <RefreshCw className="h-4 w-4 animate-spin text-black" />
              ) : (
                <Save className="h-4 w-4" />
              )}
              Update Rate to ₹{editingPrice} / Credit
            </button>
          </form>
        </div>

        {/* SECTION 1.5: DYNAMIC RECHARGE PACKAGES / PLANS MANAGEMENT */}
        <div className="glass-card rounded-3xl p-6 sm:p-8 border border-purple-500/30 space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-xl font-extrabold text-white flex items-center gap-2">
                <Package className="h-5 w-5 text-purple-400" />
                Credit Purchase Packages & Plans
              </h2>
              <p className="text-xs text-slate-400 mt-1">
                Add, edit, or remove custom credit plans displayed on the website recharge portal.
              </p>
            </div>

            <div className="flex items-center gap-2">
              {customPacks.length === 0 && (
                <button
                  onClick={handleSeedDefaultPacks}
                  className="px-3.5 py-2 rounded-xl glass-panel hover:bg-slate-800 border border-white/10 text-xs font-bold text-slate-300 transition"
                >
                  Load Default Plans
                </button>
              )}
              <button
                onClick={handleOpenCreatePackModal}
                className="px-4 py-2 rounded-xl bg-purple-500 text-white font-extrabold text-xs uppercase tracking-wider hover:bg-purple-400 transition flex items-center gap-1.5 shadow-lg shadow-purple-500/20"
              >
                <Plus className="h-4 w-4" /> Add New Plan
              </button>
            </div>
          </div>

          {/* Packages Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {customPacks.length === 0 ? (
              <div className="sm:col-span-2 lg:col-span-4 p-8 text-center glass-panel rounded-2xl border border-white/10">
                <Package className="h-8 w-8 mx-auto text-slate-500 mb-2" />
                <p className="text-sm font-bold text-slate-300">No Custom Plans Created Yet</p>
                <p className="text-xs text-slate-400 mt-1 mb-4">
                  Default 1, 3, 5, and 10 Credit plans are currently being displayed on the site.
                </p>
                <button
                  onClick={handleSeedDefaultPacks}
                  className="px-4 py-2 rounded-xl bg-cyan-500 text-black font-bold text-xs uppercase tracking-wider"
                >
                  Click Here to Initialize Customizable Plans
                </button>
              </div>
            ) : (
              customPacks.map((pack) => (
                <div
                  key={pack.id}
                  className={`glass-card p-5 rounded-2xl border flex flex-col justify-between relative transition ${
                    pack.recommended
                      ? "border-cyan-500/60 shadow-lg shadow-cyan-500/10"
                      : "border-white/10"
                  }`}
                >
                  {pack.tag && (
                    <span className="absolute -top-3 right-4 px-2.5 py-0.5 rounded-full bg-cyan-500 text-black font-extrabold text-[10px] uppercase">
                      {pack.tag}
                    </span>
                  )}

                  <div>
                    <div className="flex items-center justify-between gap-2 mb-2">
                      <h4 className="font-extrabold text-base text-white">{pack.title}</h4>
                      {pack.recommended && <Star className="h-4 w-4 text-amber-400 fill-amber-400" />}
                    </div>

                    <div className="text-2xl font-black text-cyan-400 mb-1">
                      ₹{pack.price}
                    </div>

                    <div className="text-xs font-semibold text-slate-300 mb-3 flex items-center gap-1">
                      <Sparkles className="h-3.5 w-3.5 text-cyan-400" />
                      +{pack.credits} Search Credits
                    </div>

                    <p className="text-[11px] text-slate-400 border-t border-white/5 pt-2">
                      {pack.desc || `${pack.credits} Full Number Search Lookups`}
                    </p>
                  </div>

                  <div className="flex items-center gap-2 pt-4 border-t border-white/10 mt-4">
                    <button
                      onClick={() => handleOpenEditPackModal(pack)}
                      className="w-1/2 py-1.5 rounded-lg glass-panel hover:bg-cyan-500/20 text-cyan-300 font-bold text-xs flex items-center justify-center gap-1 transition"
                    >
                      <Edit3 className="h-3.5 w-3.5" /> Edit
                    </button>
                    <button
                      onClick={() => handleDeletePack(pack.id, pack.title)}
                      className="w-1/2 py-1.5 rounded-lg bg-rose-500/20 text-rose-300 hover:bg-rose-500/30 font-bold text-xs flex items-center justify-center gap-1 transition"
                    >
                      <Trash2 className="h-3.5 w-3.5" /> Delete
                    </button>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* SECTION 2: USER CREDIT MANAGEMENT */}
        <div className="glass-card rounded-3xl p-6 sm:p-8 border border-white/10 space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
            <div>
              <h2 className="text-xl font-extrabold text-white flex items-center gap-2">
                <Users className="h-5 w-5 text-cyan-400" />
                User Accounts & Credit Balance Management
              </h2>
              <p className="text-xs text-slate-400 mt-1">
                Select any registered user below to instantly grant or deduct credit balance.
              </p>
            </div>

            {/* Search Input */}
            <div className="relative w-full sm:w-72">
              <Search className="absolute left-3.5 top-3 h-4 w-4 text-slate-400" />
              <input
                type="text"
                value={userSearchQuery}
                onChange={(e) => setUserSearchQuery(e.target.value)}
                placeholder="Search user by email or name..."
                className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-900 border border-white/10 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-400"
              />
            </div>
          </div>

          {/* Users Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-white/10 text-xs uppercase text-slate-400 font-mono">
                  <th className="py-3 px-4">User</th>
                  <th className="py-3 px-4">UID</th>
                  <th className="py-3 px-4">Current Credits</th>
                  <th className="py-3 px-4">Purchase Rate (₹/Cr)</th>
                  <th className="py-3 px-4 text-right">Quick Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5 text-xs">
                {filteredUsers.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-8 text-center text-slate-500">
                      No matching user accounts found in Firestore.
                    </td>
                  </tr>
                ) : (
                  filteredUsers.map((user) => (
                    <tr key={user.uid} className="hover:bg-white/5 transition">
                      <td className="py-3.5 px-4 font-semibold text-white">
                        <div>{user.displayName || "Subscriber"}</div>
                        <div className="text-[11px] text-slate-400 font-normal">{user.email}</div>
                      </td>
                      <td className="py-3.5 px-4 font-mono text-slate-400 text-[11px]">
                        {(user.uid || "").substring(0, 12)}...
                      </td>
                      <td className="py-3.5 px-4">
                        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-xl bg-cyan-500/20 text-cyan-400 font-bold border border-cyan-500/30">
                          <Sparkles className="h-3.5 w-3.5" />
                          {user.credits ?? 0} Credits
                        </span>
                      </td>
                      <td className="py-3.5 px-4">
                        {user.customPricePerCredit ? (
                          <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-lg bg-purple-500/20 text-purple-300 font-bold border border-purple-500/40 text-[11px]">
                            ₹{user.customPricePerCredit}/Credit (Custom)
                          </span>
                        ) : (
                          <span className="text-slate-400 text-[11px] font-mono">
                            ₹{pricingSettings.pricePerCredit}/Credit (Default)
                          </span>
                        )}
                      </td>
                      <td className="py-3.5 px-4 text-right">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => handleModifyUserCredits(user, 5)}
                            disabled={updatingCredits}
                            className="px-2.5 py-1 rounded-lg bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/30 font-bold text-[11px] flex items-center gap-1 transition"
                            title="Add +5 Credits"
                          >
                            <PlusCircle className="h-3.5 w-3.5" /> +5
                          </button>

                          <button
                            onClick={() => handleModifyUserCredits(user, 10)}
                            disabled={updatingCredits}
                            className="px-2.5 py-1 rounded-lg bg-cyan-500/20 text-cyan-400 border border-cyan-500/30 hover:bg-cyan-500/30 font-bold text-[11px] flex items-center gap-1 transition"
                            title="Add +10 Credits"
                          >
                            <PlusCircle className="h-3.5 w-3.5" /> +10
                          </button>

                          <button
                            onClick={() => {
                              setSelectedUser(user);
                              setCustomUserRateInput(user.customPricePerCredit?.toString() || "");
                            }}
                            className="px-3 py-1 rounded-lg bg-purple-500/20 text-purple-300 border border-purple-500/30 hover:bg-purple-500/30 font-bold text-[11px] transition"
                          >
                            Manage Rate / Credits
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* SECTION 3: RECENT GLOBAL ORDERS LOG */}
        <div className="glass-card rounded-3xl p-6 sm:p-8 border border-white/10 space-y-4">
          <h2 className="text-xl font-extrabold text-white flex items-center gap-2">
            <History className="h-5 w-5 text-purple-400" />
            Global Payflux Transactions Log
          </h2>

          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-white/10 text-xs uppercase text-slate-400 font-mono">
                  <th className="py-3 px-4">Order ID</th>
                  <th className="py-3 px-4">User ID</th>
                  <th className="py-3 px-4">Amount Paid</th>
                  <th className="py-3 px-4">Credits Granted</th>
                  <th className="py-3 px-4">Status</th>
                  <th className="py-3 px-4">Timestamp</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5 text-xs font-mono">
                {globalOrders.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-8 text-center text-slate-500">
                      No transaction records recorded yet.
                    </td>
                  </tr>
                ) : (
                  globalOrders.map((ord) => (
                    <tr key={ord.id} className="hover:bg-white/5 transition">
                      <td className="py-3 px-4 font-bold text-slate-200">#{ord.orderId || "N/A"}</td>
                      <td className="py-3 px-4 text-slate-400">{(ord.userId || "").substring(0, 10)}...</td>
                      <td className="py-3 px-4 font-bold text-emerald-400">₹{ord.amount}</td>
                      <td className="py-3 px-4 text-cyan-400 font-bold">+{ord.creditsAdded} Credits</td>
                      <td className="py-3 px-4">
                        <span
                          className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                            ord.status === "SUCCESS"
                              ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                              : "bg-amber-500/20 text-amber-400 border border-amber-500/30"
                          }`}
                        >
                          {ord.status}
                        </span>
                      </td>
                      <td className="py-3 px-4 text-slate-400 text-[11px]">
                        {formatDate(ord.timestamp?.seconds)}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* CUSTOM CREDIT MODAL */}
      {selectedUser && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="glass-card max-w-md w-full p-6 rounded-3xl border border-cyan-500/30 space-y-6 max-h-[90vh] overflow-y-auto">
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <Sparkles className="h-5 w-5 text-cyan-400" />
              Manage Settings for {selectedUser.displayName || selectedUser.email}
            </h3>

            <div className="p-3.5 rounded-xl bg-slate-900 border border-white/10 text-xs space-y-1.5 font-mono">
              <div className="text-slate-400">User Email: <span className="text-slate-200">{selectedUser.email}</span></div>
              <div className="text-slate-400">Current Balance: <span className="text-cyan-400 font-bold">{selectedUser.credits} Credits</span></div>
              <div className="text-slate-400">Current Rate: <span className="text-purple-300 font-bold">₹{selectedUser.customPricePerCredit || pricingSettings.pricePerCredit}/Credit {selectedUser.customPricePerCredit ? "(Custom Rate)" : "(Global Default)"}</span></div>
            </div>

            {/* TAB 1: MODIFIED CREDITS */}
            <div className="space-y-3 pt-1 border-t border-white/10">
              <label className="block text-xs font-bold uppercase text-cyan-400 tracking-wider">
                1. Grant / Deduct Credits
              </label>
              <div className="flex gap-2">
                <input
                  type="number"
                  value={creditAmountInput}
                  onChange={(e) => setCreditAmountInput(Number(e.target.value))}
                  placeholder="e.g. 10 or -5"
                  className="w-full px-4 py-2 rounded-xl bg-slate-900 border border-white/10 text-white font-bold text-sm focus:outline-none focus:border-cyan-400"
                />
                <button
                  onClick={() => handleModifyUserCredits(selectedUser, creditAmountInput)}
                  disabled={updatingCredits}
                  className="px-4 py-2 rounded-xl bg-cyan-500 text-black font-extrabold text-xs uppercase hover:bg-cyan-400 transition whitespace-nowrap"
                >
                  Update Balance
                </button>
              </div>
            </div>

            {/* TAB 2: PER-USER CUSTOM RATE */}
            <div className="space-y-3 pt-3 border-t border-white/10">
              <label className="block text-xs font-bold uppercase text-purple-400 tracking-wider">
                2. Set Custom Price Rate (₹ per Credit)
              </label>
              <p className="text-[11px] text-slate-400">
                Define how much ₹ this specific user pays per credit. Leave empty to reset to global default rate (₹{pricingSettings.pricePerCredit}/Credit).
              </p>
              
              <div className="flex gap-2">
                <div className="relative w-full">
                  <span className="absolute left-3 top-2.5 text-xs font-bold text-purple-400">₹</span>
                  <input
                    type="number"
                    min={1}
                    value={customUserRateInput}
                    onChange={(e) => setCustomUserRateInput(e.target.value)}
                    placeholder={`Default: ₹${pricingSettings.pricePerCredit}`}
                    className="w-full pl-7 pr-3 py-2 rounded-xl bg-slate-900 border border-white/10 text-white font-bold text-sm focus:outline-none focus:border-purple-400"
                  />
                </div>

                <button
                  onClick={() =>
                    handleSetCustomUserRate(
                      selectedUser,
                      customUserRateInput.trim() !== "" ? Number(customUserRateInput) : null
                    )
                  }
                  disabled={updatingCredits}
                  className="px-4 py-2 rounded-xl bg-purple-500 text-white font-extrabold text-xs uppercase hover:bg-purple-400 transition whitespace-nowrap"
                >
                  Save Custom Rate
                </button>
              </div>

              {selectedUser.customPricePerCredit && (
                <button
                  onClick={() => handleSetCustomUserRate(selectedUser, null)}
                  disabled={updatingCredits}
                  className="w-full py-2 rounded-xl bg-rose-500/20 text-rose-300 border border-rose-500/30 hover:bg-rose-500/30 text-xs font-bold transition"
                >
                  Reset to Global Default Rate (₹{pricingSettings.pricePerCredit}/Credit)
                </button>
              )}
            </div>

            <div className="pt-2">
              <button
                onClick={() => setSelectedUser(null)}
                className="w-full py-2.5 rounded-xl glass-panel text-slate-300 font-semibold text-xs uppercase"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ADD / EDIT RECHARGE PACKAGE MODAL */}
      {isPackModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="glass-card max-w-md w-full p-6 rounded-3xl border border-purple-500/40 space-y-6 max-h-[90vh] overflow-y-auto">
            <h3 className="text-lg font-bold text-white flex items-center gap-2">
              <Package className="h-5 w-5 text-purple-400" />
              {editingPack ? "Edit Credit Package" : "Create New Credit Package"}
            </h3>

            <form onSubmit={handleSavePack} className="space-y-4 text-left">
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Plan Title
                </label>
                <input
                  type="text"
                  required
                  value={packTitle}
                  onChange={(e) => setPackTitle(e.target.value)}
                  placeholder="e.g. Starter Pack, Pro Pack"
                  className="w-full px-4 py-2.5 rounded-xl bg-slate-900 border border-white/10 text-white text-sm focus:outline-none focus:border-purple-400"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">
                    Credits Count
                  </label>
                  <input
                    type="number"
                    min={1}
                    required
                    value={packCredits}
                    onChange={(e) => {
                      const c = Number(e.target.value);
                      setPackCredits(c);
                      if (!editingPack) {
                        setPackPrice(c * pricingSettings.pricePerCredit);
                      }
                    }}
                    placeholder="e.g. 5"
                    className="w-full px-4 py-2.5 rounded-xl bg-slate-900 border border-white/10 text-white font-bold text-sm focus:outline-none focus:border-purple-400"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-1">
                    Price in ₹
                  </label>
                  <input
                    type="number"
                    min={1}
                    required
                    value={packPrice}
                    onChange={(e) => setPackPrice(Number(e.target.value))}
                    placeholder="e.g. 200"
                    className="w-full px-4 py-2.5 rounded-xl bg-slate-900 border border-white/10 text-white font-bold text-sm focus:outline-none focus:border-purple-400 text-cyan-400"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Tag / Badge (Optional)
                </label>
                <input
                  type="text"
                  value={packTag}
                  onChange={(e) => setPackTag(e.target.value)}
                  placeholder="e.g. Best Value, Popular, 20% Extra"
                  className="w-full px-4 py-2.5 rounded-xl bg-slate-900 border border-white/10 text-white text-sm focus:outline-none focus:border-purple-400"
                />
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Description
                </label>
                <input
                  type="text"
                  value={packDesc}
                  onChange={(e) => setPackDesc(e.target.value)}
                  placeholder="e.g. 5 Full Number Search Lookups"
                  className="w-full px-4 py-2.5 rounded-xl bg-slate-900 border border-white/10 text-white text-sm focus:outline-none focus:border-purple-400"
                />
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="packRecommended"
                  checked={packRecommended}
                  onChange={(e) => setPackRecommended(e.target.checked)}
                  className="h-4 w-4 rounded bg-slate-900 border-white/20 text-purple-500 focus:ring-purple-400"
                />
                <label htmlFor="packRecommended" className="text-xs font-semibold text-slate-300 cursor-pointer select-none">
                  Highlight as Recommended Plan
                </label>
              </div>

              <div className="flex items-center gap-3 pt-4 border-t border-white/10">
                <button
                  type="button"
                  onClick={() => setIsPackModalOpen(false)}
                  className="w-1/2 py-2.5 rounded-xl glass-panel text-slate-300 font-semibold text-xs uppercase"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingPack}
                  className="w-1/2 py-2.5 rounded-xl bg-purple-500 text-white font-extrabold text-xs uppercase tracking-wider hover:bg-purple-400 transition flex items-center justify-center gap-1 shadow-lg shadow-purple-500/20"
                >
                  {savingPack ? (
                    <RefreshCw className="h-4 w-4 animate-spin" />
                  ) : (
                    <Save className="h-4 w-4" />
                  )}
                  Save Plan
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </main>
  );
}

export default function AdminPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-[#0B0F17] flex items-center justify-center text-cyan-400 font-bold text-sm">
          Loading Admin Control Panel...
        </div>
      }
    >
      <AdminPageContent />
    </Suspense>
  );
}
