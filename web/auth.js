const AUTH_DEFAULT_API_BASE = "http://127.0.0.1:8000/api";
const THEME_STORAGE_KEY = "coforge_theme";
const CURRENT_USER_STORAGE_KEY = "currentUser";
const MOCK_ACCESS_TOKEN_PREFIX = "mock-token-";
const LOCAL_PROFILE_MAP = {
  "beyza@polat.com": {
    full_name: "Beyza Polat",
    email: "beyza@polat.com",
    title: "Software Engineer - Firat Uni",
    skills: ["Python", "Django", "Flutter", "Milvus", "React", "SQL"],
    avatar_url: "",
  },
  "ali@yilmaz.com": {
    full_name: "Ali Yilmaz",
    email: "ali@yilmaz.com",
    title: "Backend Developer",
    bio: "CRM ve gorev takip sistemleri; Django REST, PostgreSQL, Docker.",
    skills: ["Python", "Django", "REST API", "PostgreSQL", "Docker", "CRM"],
    avatar_url: "",
  },
  "ayse@demir.com": {
    full_name: "Ayse Demir",
    email: "ayse@demir.com",
    title: "AI / NLP Engineer",
    bio: "Makale ozetleme, embedding ve LLM tabanli urunler.",
    skills: ["Python", "NLP", "LLM", "OpenAI", "PyTorch", "Transformer", "Milvus"],
    avatar_url: "",
  },
};

function authGetApiBase() {
  const stored = localStorage.getItem("coforge_api_base");
  const raw = (stored || AUTH_DEFAULT_API_BASE).trim();
  return raw.endsWith("/") ? raw.slice(0, -1) : raw;
}

function authSetApiBase(value) {
  const raw = (value || AUTH_DEFAULT_API_BASE).trim();
  const normalized = raw.endsWith("/") ? raw.slice(0, -1) : raw;
  localStorage.setItem("coforge_api_base", normalized);
}

function authGetToken() {
  return (localStorage.getItem("coforge_access_token") || "").trim();
}

function authSetToken(token) {
  localStorage.setItem("coforge_access_token", (token || "").trim());
}

function authClearSession() {
  localStorage.removeItem("coforge_access_token");
  localStorage.removeItem(CURRENT_USER_STORAGE_KEY);
}

function authSetCurrentUser(user) {
  if (!user || typeof user !== "object") return;
  localStorage.setItem(CURRENT_USER_STORAGE_KEY, JSON.stringify(user));
}

function authGetCurrentUser() {
  const raw = (localStorage.getItem(CURRENT_USER_STORAGE_KEY) || "").trim();
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch (_err) {
    return null;
  }
}

function authRequireCurrentUser() {
  const currentUser = authGetCurrentUser();
  if (!currentUser) {
    authClearSession();
    window.location.href = "login.html";
    return null;
  }
  return currentUser;
}

async function authTryFetchCurrentUserFromBackend() {
  const resp = await fetch(`${authGetApiBase()}/me/profile/`, {
    method: "GET",
    headers: authHeaders(),
  });
  const data = await authParseResponse(resp);
  return {
    full_name: data.full_name || data.user_full_name || data.name || "",
    email: data.email || data.user_email || "",
    title: data.title || "",
    bio: data.bio || "",
    avatar_url: data.avatar_url || "",
    github_url: data.github_url || "",
    linkedin_url: data.linkedin_url || "",
    skills: Array.isArray(data.skills) ? data.skills : [],
  };
}

async function authRefreshCurrentUserFromBackend() {
  const token = authGetToken();
  if (!token) return authGetCurrentUser();
  try {
    const profileData = await authTryFetchCurrentUserFromBackend();
    const prev = authGetCurrentUser() || {};
    const merged = {
      ...prev,
      ...profileData,
      email: profileData.email || prev.email || "",
    };
    authSetCurrentUser(merged);
    if (merged.avatar_url) {
      localStorage.setItem("userProfilePic", merged.avatar_url);
    } else {
      localStorage.removeItem("userProfilePic");
    }
    return merged;
  } catch (_err) {
    return authGetCurrentUser();
  }
}

async function authLoginViaBackend(email, password) {
  const resp = await fetch(`${authGetApiBase()}/auth/login/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  const data = await authParseResponse(resp);
  authSetToken(data.access || "");

  let currentUser = {
    full_name: data.full_name || data.name || email.split("@")[0],
    email,
    title: data.title || "",
    avatar_url: data.avatar_url || "",
    skills: Array.isArray(data.skills) ? data.skills : [],
  };

  try {
    const profileData = await authTryFetchCurrentUserFromBackend();
    currentUser = { ...currentUser, ...profileData, email: profileData.email || email };
  } catch (_err) {
    // Backend profile endpoint olmayabilir; login response ile devam et.
  }

  authSetCurrentUser(currentUser);
  return { source: "backend", user: currentUser };
}

function authLoginViaMock(email) {
  const safeEmail = String(email || "").trim().toLowerCase();
  const emailName = safeEmail.includes("@") ? safeEmail.split("@")[0] : "kullanici";
  const fallbackFullName =
    emailName
      .split(/[._-]/g)
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
      .join(" ") || "Yeni Kullanici";
  const preset = LOCAL_PROFILE_MAP[safeEmail] || null;
  const mockUser = preset || {
    full_name: fallbackFullName,
    email: safeEmail,
    title: "CoForge Uyesi",
    skills: [],
    avatar_url: "",
  };

  authSetToken(`${MOCK_ACCESS_TOKEN_PREFIX}${safeEmail}`);
  authSetCurrentUser(mockUser);
  return { source: "mock", user: mockUser };
}

async function authLogin(email, password) {
  const safeEmail = (email || "").trim();
  const safePassword = (password || "").trim();
  if (!safeEmail || !safePassword) {
    throw new Error("E-posta ve sifre zorunludur.");
  }

  // Her yeni giriste sadece oturum verisini temizle; kullaniciya ait proje kayitlarini silme.
  authClearSession();

  try {
    return await authLoginViaBackend(safeEmail, safePassword);
  } catch (_err) {
    // Backend yoksa veya test ortamiysa mock ile devam et.
    return authLoginViaMock(safeEmail);
  }
}

function requireAuth() {
  if (!authGetToken()) {
    window.location.href = "login.html";
    return false;
  }
  if (!authGetCurrentUser()) {
    authClearSession();
    window.location.href = "login.html";
    return false;
  }
  return true;
}

function redirectIfAuthenticated() {
  if (authGetToken() && authGetCurrentUser()) {
    window.location.href = "index.html";
    return true;
  }
  return false;
}

function authHeaders(withJson = false) {
  const headers = {};
  const token = authGetToken();
  if (withJson) headers["Content-Type"] = "application/json";
  if (token) headers.Authorization = `Bearer ${token}`;
  return headers;
}

function authIsMockSession() {
  return authGetToken().startsWith(MOCK_ACCESS_TOKEN_PREFIX);
}

/**
 * Acik ilan listesi / detay (GET) icin. Mock oturumdaki "mock-token-..." gecerli JWT
 * degildir; DRF 401 doner. Herkesin ayni sunucu ilanlarini gorebilmesi icin
 * bu isteklerde Authorization gonderilmez; sunucu list/retrieve icin AllowAny kullanir.
 */
function authHeadersForPublicRead() {
  if (authIsMockSession()) return {};
  return authHeaders();
}

const COFORGE_LOCAL_POST_PREFIX = "coforge_local_post_";

function coforgeSaveLocalProjectPost(post) {
  if (!post || !post.id) return;
  localStorage.setItem(`${COFORGE_LOCAL_POST_PREFIX}${post.id}`, JSON.stringify(post));
}

function coforgeLoadLocalProjectPost(id) {
  const raw = (localStorage.getItem(`${COFORGE_LOCAL_POST_PREFIX}${id}`) || "").trim();
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch (_err) {
    return null;
  }
}

/** Tüm tarayıcıda saklı (mock / offline) ilanları döndürür; ana sayfa akışında API ile birleştirmek için. */
function coforgeListAllLocalProjectPosts() {
  const out = [];
  for (let i = 0; i < localStorage.length; i += 1) {
    const key = localStorage.key(i);
    if (!key || !key.startsWith(COFORGE_LOCAL_POST_PREFIX)) continue;
    const id = key.slice(COFORGE_LOCAL_POST_PREFIX.length);
    const post = coforgeLoadLocalProjectPost(id);
    if (post) out.push(post);
  }
  return out;
}

/** DRF / Django REST: { detail } veya alan bazli { email: ["..."], password: ["..."] } */
function authSummarizeApiError(data) {
  if (!data || typeof data !== "object") return "";
  const parts = [];

  if (data.detail != null) {
    if (typeof data.detail === "string") {
      parts.push(data.detail);
    } else if (Array.isArray(data.detail)) {
      data.detail.forEach((item) => {
        if (typeof item === "string") parts.push(item);
        else if (item && typeof item === "object" && item.string) parts.push(String(item.string));
        else parts.push(JSON.stringify(item));
      });
    }
  }

  for (const [key, val] of Object.entries(data)) {
    if (key === "detail") continue;
    const label = key;
    if (Array.isArray(val)) {
      val.forEach((m) => parts.push(`${label}: ${typeof m === "string" ? m : JSON.stringify(m)}`));
    } else if (val != null && typeof val === "object") {
      parts.push(`${label}: ${JSON.stringify(val)}`);
    } else if (val != null && val !== "") {
      parts.push(`${label}: ${String(val)}`);
    }
  }

  return parts.filter(Boolean).join("\n");
}

async function authParseResponse(resp) {
  const data = await resp.json().catch(() => ({}));
  if (resp.status === 401) {
    const token = authGetToken();
    const isMockSession = token.startsWith(MOCK_ACCESS_TOKEN_PREFIX);
    if (!isMockSession) {
      authClearSession();
      window.location.href = "login.html";
      throw new Error("Oturum suresi dolmus. Lutfen tekrar giris yapin.");
    }
    throw new Error(data.detail || "Mock oturumda backend yetkisi yok.");
  }
  if (!resp.ok) {
    const summary = authSummarizeApiError(data);
    throw new Error(summary || data.error || `HTTP ${resp.status}`);
  }
  return data;
}

function getSavedTheme() {
  const saved = localStorage.getItem(THEME_STORAGE_KEY);
  if (saved === "light" || saved === "dark") return saved;
  if (typeof window !== "undefined" && window.matchMedia?.("(prefers-color-scheme: light)")?.matches) {
    return "light";
  }
  return "dark";
}

function setThemeIcon(button, isLight) {
  if (!button) return;
  button.innerHTML = isLight
    ? '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4.25a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-1.5 0V5a.75.75 0 0 1 .75-.75Zm0 12.5a.75.75 0 0 1 .75.75V19a.75.75 0 0 1-1.5 0v-1.5a.75.75 0 0 1 .75-.75ZM5.99 6.99a.75.75 0 0 1 1.06 0l1.06 1.06a.75.75 0 1 1-1.06 1.06L5.99 8.05a.75.75 0 0 1 0-1.06Zm9.9 9.9a.75.75 0 0 1 1.06 0l1.06 1.06a.75.75 0 1 1-1.06 1.06l-1.06-1.06a.75.75 0 0 1 0-1.06ZM4.25 12a.75.75 0 0 1 .75-.75h1.5a.75.75 0 0 1 0 1.5H5a.75.75 0 0 1-.75-.75Zm12.5 0a.75.75 0 0 1 .75-.75H19a.75.75 0 0 1 0 1.5h-1.5a.75.75 0 0 1-.75-.75ZM8.11 15.89a.75.75 0 0 1 0 1.06l-1.06 1.06a.75.75 0 1 1-1.06-1.06l1.06-1.06a.75.75 0 0 1 1.06 0Zm9.9-9.9a.75.75 0 0 1 0 1.06l-1.06 1.06a.75.75 0 1 1-1.06-1.06l1.06-1.06a.75.75 0 0 1 1.06 0ZM12 8.5a3.5 3.5 0 1 1 0 7 3.5 3.5 0 0 1 0-7Z"/></svg>'
    : '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14.51 3.75a.75.75 0 0 1 .6 1.2A8.25 8.25 0 1 0 19.05 14.9a.75.75 0 0 1 1.2.6 9.75 9.75 0 1 1-5.15-11.54.75.75 0 0 1-.59-.2Z"/></svg>';
  button.setAttribute("aria-label", isLight ? "Koyu moda gec" : "Aydinlik moda gec");
  button.setAttribute("title", isLight ? "Koyu moda gec" : "Aydinlik moda gec");
}

function applyTheme(theme) {
  const isLight = theme === "light";
  document.body.classList.toggle("light-mode", isLight);
  document.body.classList.toggle("light-theme", isLight);
  setThemeIcon(document.getElementById("themeToggle"), isLight);
}

/** Kullanici silueti (SVG), currentColor ile temaya uyum */
const COFORGE_AVATAR_SILHOUETTE_SVG = `<svg class="coforge-avatar-silhouette-svg" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path fill="currentColor" d="M32 36c7.7 0 14-6.3 14-14S39.7 8 32 8 18 14.3 18 22s6.3 14 14 14Zm0 4c-12.7 0-22 7.9-22 18a2 2 0 0 0 2 2h40a2 2 0 0 0 2-2c0-10.1-9.3-18-22-18Z"/></svg>`;

function coforgeEscapeAttr(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

const COFORGE_AVATAR_EXTRA_CLASS = {
  header: "header-profile-avatar",
  profile: "profile-avatar",
  card: "avatar",
  detail: "avatar",
  settings: "avatar-preview-image",
};

function coforgeCreateAvatarPlaceholder(variant) {
  const v = variant || "card";
  const el = document.createElement("div");
  const extra = COFORGE_AVATAR_EXTRA_CLASS[v] || "";
  el.className = ["coforge-avatar-placeholder", `coforge-avatar-placeholder--${v}`, extra].filter(Boolean).join(" ");
  el.setAttribute("role", "img");
  el.setAttribute("aria-label", "Profil fotografi yok");
  el.innerHTML = COFORGE_AVATAR_SILHOUETTE_SVG;
  return el;
}

/**
 * Hedef konteyneri temizleyip ya <img> ya da placeholder koyar.
 * @param {HTMLElement|null} container
 * @param {string} url
 * @param {"header"|"profile"|"card"|"detail"|"settings"} variant
 */
function coforgeRenderAvatarTo(container, url, variant) {
  if (!container) return;
  container.replaceChildren();
  const trimmed = String(url || "").trim();
  const v = variant || "card";
  if (!trimmed) {
    container.appendChild(coforgeCreateAvatarPlaceholder(v));
    return;
  }
  const img = document.createElement("img");
  const extra = COFORGE_AVATAR_EXTRA_CLASS[v] || "";
  img.className = extra;
  img.alt = v === "header" || v === "profile" || v === "settings" ? "Profil fotografi" : "Kullanici avatarı";
  img.setAttribute("data-coforge-avatar-variant", v);
  img.src = trimmed;
  img.addEventListener("error", () => {
    img.replaceWith(coforgeCreateAvatarPlaceholder(v));
  });
  container.appendChild(img);
}

function coforgeHandleAvatarImgError(img) {
  if (!img || !img.parentNode) return;
  const v = img.getAttribute("data-coforge-avatar-variant") || "card";
  img.replaceWith(coforgeCreateAvatarPlaceholder(v));
}

function coforgeAvatarOuterHTML(url, variant) {
  const trimmed = String(url || "").trim();
  const v = variant || "card";
  if (!trimmed) {
    const phClasses = ["coforge-avatar-placeholder", `coforge-avatar-placeholder--${v}`, COFORGE_AVATAR_EXTRA_CLASS[v]].filter(Boolean).join(" ");
    return `<div class="${phClasses}" role="img" aria-label="Profil fotografi yok">${COFORGE_AVATAR_SILHOUETTE_SVG}</div>`;
  }
  const cls = COFORGE_AVATAR_EXTRA_CLASS[v] || "avatar";
  return `<img class="${cls}" src="${coforgeEscapeAttr(trimmed)}" alt="Kullanici avatarı" data-coforge-avatar-variant="${v}" onerror="window.coforgeHandleAvatarImgError(this)">`;
}

if (typeof window !== "undefined") {
  window.coforgeHandleAvatarImgError = coforgeHandleAvatarImgError;
}

function coforgeInitTheme(toggleId = "themeToggle") {
  const toggle = document.getElementById(toggleId);
  applyTheme(getSavedTheme());
  if (!toggle) return;
  toggle.addEventListener("click", () => {
    const next = document.body.classList.contains("light-mode") ? "dark" : "light";
    localStorage.setItem(THEME_STORAGE_KEY, next);
    applyTheme(next);
  });
}

function coforgeInitHeaderAvatar(buttonId = "profileMenuToggle") {
  const button = document.getElementById(buttonId);
  if (!button) return;

  const user = authGetCurrentUser();
  const fromUser = (user && user.avatar_url ? String(user.avatar_url) : "").trim();
  const savedProfilePic = (localStorage.getItem("userProfilePic") || "").trim();
  const url = fromUser || savedProfilePic;

  coforgeRenderAvatarTo(button, url, "header");
}

const COFORGE_FLASH_TOAST_KEY = "coforge_flash_toast";

function coforgeFlashToast(message, isError = false) {
  try {
    sessionStorage.setItem(
      COFORGE_FLASH_TOAST_KEY,
      JSON.stringify({ message: String(message || ""), isError: !!isError })
    );
  } catch (_e) {
    /* ignore */
  }
}

function coforgeConsumeFlashToast() {
  try {
    const raw = sessionStorage.getItem(COFORGE_FLASH_TOAST_KEY);
    if (!raw) return null;
    sessionStorage.removeItem(COFORGE_FLASH_TOAST_KEY);
    return JSON.parse(raw);
  } catch (_e) {
    return null;
  }
}

function coforgeShowToast(message, isError = false) {
  const toast = document.createElement("div");
  toast.className = `settings-toast toast-top-right${isError ? " error" : ""}`;
  toast.setAttribute("role", "status");
  toast.innerHTML = `
    <span class="settings-toast-icon">${isError ? "!" : "✓"}</span>
    <span class="settings-toast-text"></span>
  `;
  const textEl = toast.querySelector(".settings-toast-text");
  if (textEl) textEl.textContent = String(message || "");
  document.body.appendChild(toast);
  requestAnimationFrame(() => toast.classList.add("show"));
  window.setTimeout(() => {
    toast.classList.remove("show");
    toast.classList.add("hide");
    window.setTimeout(() => toast.remove(), 360);
  }, 3200);
}
