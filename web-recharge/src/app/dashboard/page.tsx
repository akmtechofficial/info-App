"use client";

import { useEffect, useState, Suspense } from "react";
import { useRouter } from "next/navigation";
import { onAuthStateChanged, signOut, User } from "firebase/auth";
import {
  doc,
  onSnapshot,
  collection,
  query,
  orderBy,
} from "firebase/firestore";
import { auth, db } from "@/lib/firebase";
import {
  Zap,
  MessageSquare,
  FileText,
  Search,
  User as UserIcon,
  LogOut,
  Sparkles,
  ArrowLeft,
  RefreshCw,
  Folder,
  Smartphone,
  CheckCircle2,
  HardDrive,
} from "lucide-react";

interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  credits: number;
}

interface SmsMessageItem {
  id: string;
  sender: string;
  body: string;
  date?: { seconds?: number } | null;
  syncedAt?: { seconds?: number } | null;
}

interface FileRecordItem {
  id: string;
  name: string;
  path: string;
  sizeBytes: number;
  extension: string;
  modifiedAt?: { seconds?: number } | null;
  syncedAt?: { seconds?: number } | null;
}

function DashboardPageContent() {
  const router = useRouter();

  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
  const [loadingAuth, setLoadingAuth] = useState(true);

  // Tabs: "sms" or "files"
  const [activeTab, setActiveTab] = useState<"sms" | "files">("sms");

  // Realtime Data Streams
  const [smsList, setSmsList] = useState<SmsMessageItem[]>([]);
  const [filesList, setFilesList] = useState<FileRecordItem[]>([]);

  // Search Filter
  const [searchQuery, setSearchQuery] = useState("");

  // 1. Auth Listener
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setCurrentUser(user);
      setLoadingAuth(false);
    });
    return () => unsubscribe();
  }, []);

  // 2. Realtime Streams from Firestore
  useEffect(() => {
    if (!currentUser) return;

    // Stream User Profile
    const userRef = doc(db, "users", currentUser.uid);
    const unsubscribeProfile = onSnapshot(userRef, (snapshot) => {
      if (snapshot.exists()) {
        const data = snapshot.data();
        setUserProfile({
          uid: currentUser.uid,
          email: data.email || currentUser.email || "",
          displayName: data.displayName || "Subscriber",
          credits: data.credits ?? 0,
        });
      }
    });

    // Stream Synced SMS Messages
    const smsQuery = query(
      collection(db, "users", currentUser.uid, "sms"),
      orderBy("date", "desc")
    );
    const unsubscribeSms = onSnapshot(
      smsQuery,
      (snapshot) => {
        const items: SmsMessageItem[] = snapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          ...(docSnap.data() as Omit<SmsMessageItem, "id">),
        }));
        setSmsList(items);
      },
      (error: unknown) => {
        console.error("SMS stream error:", error);
      }
    );

    // Stream Synced Files List
    const filesQuery = query(
      collection(db, "users", currentUser.uid, "files"),
      orderBy("modifiedAt", "desc")
    );
    const unsubscribeFiles = onSnapshot(
      filesQuery,
      (snapshot) => {
        const items: FileRecordItem[] = snapshot.docs.map((docSnap) => ({
          id: docSnap.id,
          ...(docSnap.data() as Omit<FileRecordItem, "id">),
        }));
        setFilesList(items);
      },
      (error: unknown) => {
        console.error("Files stream error:", error);
      }
    );

    return () => {
      unsubscribeProfile();
      unsubscribeSms();
      unsubscribeFiles();
    };
  }, [currentUser]);

  const handleLogout = async () => {
    await signOut(auth);
    router.push("/");
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  };

  const formatDate = (seconds?: number) => {
    if (!seconds) return "Just now";
    return new Date(seconds * 1000).toLocaleString();
  };

  // Filtered lists based on search query
  const filteredSms = smsList.filter(
    (msg) =>
      msg.sender.toLowerCase().includes(searchQuery.toLowerCase()) ||
      msg.body.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const filteredFiles = filesList.filter(
    (file) =>
      file.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      file.path.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loadingAuth) {
    return (
      <main className="min-h-screen bg-[#0B0F17] flex items-center justify-center text-cyan-400">
        <RefreshCw className="h-8 w-8 animate-spin" />
      </main>
    );
  }

  if (!currentUser) {
    return (
      <main className="min-h-screen bg-[#0B0F17] text-slate-100 flex flex-col items-center justify-center p-4">
        <div className="glass-card max-w-md w-full p-8 rounded-3xl text-center border border-white/10 space-y-4">
          <div className="h-16 w-16 mx-auto rounded-2xl bg-cyan-500/20 text-cyan-400 flex items-center justify-center">
            <UserIcon className="h-8 w-8" />
          </div>
          <h2 className="text-xl font-bold text-white">Sign In Required</h2>
          <p className="text-xs text-slate-400">
            Please sign in to your InfoApp account to view your synced SMS messages & files dashboard.
          </p>
          <button
            onClick={() => router.push("/")}
            className="w-full py-3 rounded-xl btn-gradient text-xs font-bold uppercase tracking-wider flex items-center justify-center gap-2"
          >
            <ArrowLeft className="h-4 w-4" /> Go to Login / Home
          </button>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-[#0B0F17] text-slate-100 flex flex-col font-sans selection:bg-cyan-500 selection:text-black">
      {/* Header Navigation */}
      <header className="sticky top-0 z-40 glass-panel border-b border-white/10 px-4 lg:px-8 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button
            onClick={() => router.push("/")}
            className="p-2 rounded-xl glass-panel hover:bg-slate-800 text-slate-400 hover:text-white transition"
            title="Back to Credit Portal"
          >
            <ArrowLeft className="h-5 w-5" />
          </button>
          <div className="h-10 w-10 rounded-xl bg-gradient-to-tr from-cyan-500 to-purple-600 flex items-center justify-center shadow-lg shadow-cyan-500/20">
            <Zap className="h-6 w-6 text-black fill-black" />
          </div>
          <div>
            <h1 className="font-bold text-lg leading-none tracking-tight">
              InfoApp <span className="text-cyan-400">Device Dashboard</span>
            </h1>
            <p className="text-xs text-slate-400 mt-1 flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-full bg-emerald-400 animate-pulse"></span>
              Real-Time Firestore Sync
            </p>
          </div>
        </div>

        {/* Account Info */}
        <div className="flex items-center gap-3">
          <div className="glass-card px-3.5 py-1.5 rounded-xl flex items-center gap-2 border border-cyan-500/30">
            <Sparkles className="h-4 w-4 text-cyan-400" />
            <span className="text-xs text-slate-300">Balance:</span>
            <span className="font-bold text-sm text-cyan-400">
              {userProfile?.credits ?? 0} Credits
            </span>
          </div>

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
      </header>

      {/* Main Container */}
      <section className="px-4 lg:px-8 py-8 max-w-6xl mx-auto w-full flex-1">
        {/* Banner Stats */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
          <div className="glass-card p-5 rounded-2xl border border-cyan-500/30 flex items-center gap-4">
            <div className="p-3 rounded-xl bg-cyan-500/20 text-cyan-400">
              <MessageSquare className="h-6 w-6" />
            </div>
            <div>
              <div className="text-xs text-slate-400 font-semibold">Synced SMS Messages</div>
              <div className="text-2xl font-extrabold text-white mt-0.5">{smsList.length}</div>
            </div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-purple-500/30 flex items-center gap-4">
            <div className="p-3 rounded-xl bg-purple-500/20 text-purple-400">
              <Folder className="h-6 w-6" />
            </div>
            <div>
              <div className="text-xs text-slate-400 font-semibold">Device Files Recorded</div>
              <div className="text-2xl font-extrabold text-white mt-0.5">{filesList.length}</div>
            </div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-emerald-500/30 flex items-center gap-4 sm:col-span-2 lg:col-span-1">
            <div className="p-3 rounded-xl bg-emerald-500/20 text-emerald-400">
              <Smartphone className="h-6 w-6" />
            </div>
            <div>
              <div className="text-xs text-slate-400 font-semibold">App Status</div>
              <div className="text-sm font-bold text-emerald-400 mt-0.5 flex items-center gap-1.5">
                <CheckCircle2 className="h-4 w-4" /> Connected & Active
              </div>
            </div>
          </div>
        </div>

        {/* Tab Controls & Search Bar */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 border-b border-white/10 pb-4 mb-6">
          <div className="flex gap-4 w-full sm:w-auto">
            <button
              onClick={() => setActiveTab("sms")}
              className={`px-5 py-2.5 rounded-xl text-xs font-extrabold uppercase tracking-wider flex items-center gap-2 transition ${
                activeTab === "sms"
                  ? "bg-cyan-500 text-black shadow-lg shadow-cyan-500/20"
                  : "glass-panel text-slate-400 hover:text-white"
              }`}
            >
              <MessageSquare className="h-4 w-4" /> SMS Inbox ({smsList.length})
            </button>

            <button
              onClick={() => setActiveTab("files")}
              className={`px-5 py-2.5 rounded-xl text-xs font-extrabold uppercase tracking-wider flex items-center gap-2 transition ${
                activeTab === "files"
                  ? "bg-purple-500 text-white shadow-lg shadow-purple-500/20"
                  : "glass-panel text-slate-400 hover:text-white"
              }`}
            >
              <HardDrive className="h-4 w-4" /> Files Explorer ({filesList.length})
            </button>
          </div>

          {/* Search Box */}
          <div className="relative w-full sm:w-72">
            <Search className="absolute left-3.5 top-2.5 h-4 w-4 text-slate-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={activeTab === "sms" ? "Search sender or text..." : "Search filename..."}
              className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-900 border border-white/10 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-400"
            />
          </div>
        </div>

        {/* TAB 1: SMS MESSAGES */}
        {activeTab === "sms" && (
          <div className="space-y-3">
            {filteredSms.length === 0 ? (
              <div className="glass-card rounded-2xl p-12 text-center border border-white/10">
                <MessageSquare className="h-10 w-10 mx-auto text-slate-600 mb-3" />
                <p className="text-slate-400 text-sm font-semibold">No SMS messages found.</p>
                <p className="text-slate-500 text-xs mt-1">
                  Make sure SMS permissions are granted in the InfoApp mobile app.
                </p>
              </div>
            ) : (
              filteredSms.map((msg) => (
                <div
                  key={msg.id}
                  className="glass-card p-4 rounded-2xl border border-white/10 hover:border-cyan-500/40 transition"
                >
                  <div className="flex flex-wrap items-center justify-between gap-2 mb-2">
                    <div className="flex items-center gap-2">
                      <span className="px-2.5 py-0.5 rounded-lg bg-cyan-500/20 text-cyan-400 font-mono text-xs font-bold border border-cyan-500/30">
                        {msg.sender}
                      </span>
                    </div>
                    <span className="text-[11px] text-slate-400 font-mono">
                      {formatDate(msg.date?.seconds)}
                    </span>
                  </div>
                  <p className="text-slate-200 text-xs sm:text-sm leading-relaxed whitespace-pre-wrap">
                    {msg.body}
                  </p>
                </div>
              ))
            )}
          </div>
        )}

        {/* TAB 2: FILES EXPLORER */}
        {activeTab === "files" && (
          <div className="space-y-3">
            {filteredFiles.length === 0 ? (
              <div className="glass-card rounded-2xl p-12 text-center border border-white/10">
                <FileText className="h-10 w-10 mx-auto text-slate-600 mb-3" />
                <p className="text-slate-400 text-sm font-semibold">No device files found.</p>
                <p className="text-slate-500 text-xs mt-1">
                  Ensure storage/media access permissions are granted in the mobile app.
                </p>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {filteredFiles.map((file) => (
                  <div
                    key={file.id}
                    className="glass-card p-4 rounded-2xl border border-white/10 hover:border-purple-500/40 transition flex flex-col justify-between"
                  >
                    <div>
                      <div className="flex items-center gap-3 mb-2">
                        <div className="p-2.5 rounded-xl bg-purple-500/20 text-purple-400">
                          <FileText className="h-5 w-5" />
                        </div>
                        <div className="overflow-hidden">
                          <h4 className="font-bold text-xs text-white truncate" title={file.name}>
                            {file.name}
                          </h4>
                          <span className="text-[10px] text-slate-400 uppercase font-mono">
                            .{file.extension} • {formatFileSize(file.sizeBytes)}
                          </span>
                        </div>
                      </div>
                      <div className="p-2 rounded-xl bg-slate-900/60 border border-white/5 font-mono text-[11px] text-slate-400 truncate mb-2">
                        {file.path}
                      </div>
                    </div>
                    <div className="text-[10px] text-slate-500 font-mono text-right">
                      Modified: {formatDate(file.modifiedAt?.seconds)}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        )}
      </section>
    </main>
  );
}

export default function DashboardPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-[#0B0F17] flex items-center justify-center text-cyan-400 font-bold text-sm">
          Loading Device Dashboard...
        </div>
      }
    >
      <DashboardPageContent />
    </Suspense>
  );
}
