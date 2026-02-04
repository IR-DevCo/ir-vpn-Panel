
import { useEffect, useState } from "react";
import { motion } from "framer-motion";

interface NavbarProps {
  title?: string;
}

/**
 * Top navigation bar
 * - Displays dynamic project name
 * - Theme indicator
 * - Secure logout hook (JWT via HttpOnly cookie)
 */
export default function Navbar({ title }: NavbarProps) {
  const [projectName, setProjectName] = useState("IR - VPN");
  const [theme, setTheme] = useState<"light" | "dark">("dark");

  useEffect(() => {
    // Load branding + theme from backend settings
    const loadBranding = async () => {
      try {
        const res = await fetch("/api/settings/branding", {
          credentials: "include",
        });
        if (res.ok) {
          const data = await res.json();
          setProjectName(data.projectName || "IR - VPN");
          setTheme(data.theme || "dark");
        }
      } catch {
        // silent fail → defaults remain
      }
    };

    loadBranding();
  }, []);

  const logout = async () => {
    await fetch("/api/auth/logout", {
      method: "POST",
      credentials: "include",
    });
    window.location.href = "/";
  };

  return (
    <motion.header
      initial={{ y: -20, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.35 }}
      className="flex items-center justify-between px-6 h-16 bg-white dark:bg-gray-800 shadow"
    >
      <div className="flex flex-col">
        <span className="text-xs uppercase tracking-widest text-gray-400">
          {projectName}
        </span>
        <h1 className="text-lg font-semibold text-gray-800 dark:text-gray-100">
          {title}
        </h1>
      </div>

      <div className="flex items-center gap-4">
        <span className="text-xs px-2 py-1 rounded-lg bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300">
          {theme.toUpperCase()}
        </span>

        <button
          onClick={logout}
          className="px-4 py-2 rounded-xl bg-red-500 text-white text-sm hover:bg-red-600 transition"
        >
          Logout
        </button>
      </div>
    </motion.header>
  );
}
