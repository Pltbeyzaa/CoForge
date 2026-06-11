function setMeta(text) {
  const el = document.getElementById("matchMeta");
  if (el) el.textContent = text;
}

function initGlobalBackgroundSpotlight() {
  const root = document.body;
  root.style.setProperty("--bg-mouse-x", "50vw");
  root.style.setProperty("--bg-mouse-y", "35vh");
  window.addEventListener("mousemove", (event) => {
    root.style.setProperty("--bg-mouse-x", `${event.clientX}px`);
    root.style.setProperty("--bg-mouse-y", `${event.clientY}px`);
  });
}

function initProfileMenu() {
  const menu = document.getElementById("profileMenu");
  const toggle = document.getElementById("profileMenuToggle");
  if (!menu || !toggle) return;
  toggle.addEventListener("click", () => {
    const isOpen = menu.classList.toggle("open");
    toggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
  });
  document.addEventListener("click", (event) => {
    if (!menu.contains(event.target)) {
      menu.classList.remove("open");
      toggle.setAttribute("aria-expanded", "false");
    }
  });
}

function showSkeleton() {
  const area = document.getElementById("matchResultArea");
  if (!area) return;
  area.innerHTML = `
    <div class="match-skeleton-grid">
      <article class="match-skeleton-card">
        <span class="scan-line"></span>
        <div class="skeleton-block skeleton-title"></div>
        <div class="skeleton-block"></div>
        <div class="skeleton-block"></div>
      </article>
      <article class="match-skeleton-card">
        <span class="scan-line"></span>
        <div class="skeleton-block skeleton-title"></div>
        <div class="skeleton-block"></div>
        <div class="skeleton-block"></div>
      </article>
      <article class="match-skeleton-card">
        <span class="scan-line"></span>
        <div class="skeleton-block skeleton-title"></div>
        <div class="skeleton-block"></div>
        <div class="skeleton-block"></div>
      </article>
    </div>
  `;
}

function scoreToPercent(score) {
  const numeric = Number.parseFloat(String(score || 0));
  if (!Number.isFinite(numeric)) return 0;
  const clamped = Math.max(0, Math.min(1, numeric > 1 ? numeric / 10 : numeric));
  return Math.round(clamped * 100);
}

function escapeHtml(str) {
  return String(str || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function tierClassForPercent(p) {
  if (p >= 80) return "match-score-tier-high";
  return "match-score-tier-mid";
}

function resolveSimilarityPercent(match) {
  const n = Number(match?.similarity_percent);
  if (Number.isFinite(n)) return Math.max(0, Math.min(100, Math.round(n)));
  return scoreToPercent(match?.score);
}

function renderRequiredSkillTags(required, commonSet) {
  const list = Array.isArray(required) ? required : [];
  if (!list.length) return '<span class="tag match-skill-other">Belirtilmedi</span>';
  return list
    .map((name) => {
      const key = String(name || "").trim().toLowerCase();
      const isCommon = key && commonSet.has(key);
      const cls = isCommon ? "tag match-skill-common" : "tag match-skill-other";
      return `<span class="${cls}">${escapeHtml(name)}</span>`;
    })
    .join("");
}

function mockMatchSummary(title, common, required, userSkills) {
  const com = (common || []).slice(0, 4).join(", ");
  const tagHint = (userSkills || []).slice(0, 4).join(", ");
  if (com) {
    return `Bu ilan tam size gore cunku ${com} yetkinlikleri ilan gereksinimleriyle cakisiyor; profilinizdeki ${tagHint || "yetkinlikler"} ile uyumlu. Proje: ${title}.`;
  }
  return `Bu ilan tam size gore cunku vektor / anahtar kelime siralamasinda one cikti; profil ozeti: ${tagHint || "genel uyum"}. Proje: ${title}.`;
}

async function loadMockMatchSuggestions() {
  const user = authGetCurrentUser() || {};
  const email = String(user.email || "").trim().toLowerCase();
  const skills = Array.isArray(user.skills) ? user.skills.filter(Boolean) : [];
  const profileBlob = [user.title, user.bio || "", ...skills].join(" ").toLowerCase();

  const isAli =
    email === "ali@yilmaz.com" || (email.includes("ali") && (profileBlob.includes("backend") || skills.some((s) => /django|postgres|rest/i.test(s))));
  const isAyse =
    email === "ayse@demir.com" ||
    (email.includes("ayse") && email.includes("demir")) ||
    profileBlob.includes("nlp") ||
    profileBlob.includes("llm");

  setMeta("Mock oturum: currentUser + acik ilan listesi ile yerel eslestirme (Milvus yerine).");

  let posts = [];
  try {
    const resp = await fetch(`${authGetApiBase()}/project-posts/`, {
      method: "GET",
      headers: typeof authHeadersForPublicRead === "function" ? authHeadersForPublicRead() : {},
    });
    const raw = await resp.text();
    let data = {};
    try {
      data = raw ? JSON.parse(raw) : {};
    } catch (_e) {
      data = {};
    }
    posts = Array.isArray(data) ? data : data.results || [];
  } catch (_err) {
    posts = [];
  }

  const userSkillLower = new Set(skills.map((s) => String(s).trim().toLowerCase()).filter(Boolean));

  const scored = posts.map((p) => {
    const reqNames = (p.required_skills_detail || []).map((x) => x.skill_name).filter(Boolean);
    const common = [];
    for (const rn of reqNames) {
      const rl = String(rn).trim().toLowerCase();
      if (!rl) continue;
      if (userSkillLower.has(rl)) {
        common.push(rn);
        continue;
      }
      for (const u of userSkillLower) {
        if (rl.includes(u) || u.includes(rl)) {
          common.push(rn);
          break;
        }
      }
    }
    const overlap = common.length;
    const titleL = String(p.title || "").toLowerCase();
    let scenarioBoost = 0;
    if (isAli && (titleL.includes("crm") || titleL.includes("gorev") || titleL.includes("görev") || titleL.includes("takip"))) {
      scenarioBoost = 5000;
    }
    if (isAyse && (titleL.includes("makale") || titleL.includes("ozet") || titleL.includes("özet") || titleL.includes("nlp") || titleL.includes("llm"))) {
      scenarioBoost = 5000;
    }
    const sortKey = overlap * 80 + scenarioBoost + (String(p.description || "").length % 13);
    const similarity_percent = Math.min(99, 28 + overlap * 14 + (scenarioBoost ? 42 : 0));

    return {
      project_id: p.id,
      project_title: p.title,
      score: String(overlap),
      suggestion_status: "suggested",
      similarity_percent,
      required_skills: reqNames,
      common_skills: common,
      match_summary: mockMatchSummary(p.title, common, reqNames, skills),
      _sortKey: sortKey,
    };
  });

  scored.sort((a, b) => b._sortKey - a._sortKey);
  const matches = scored.slice(0, 12).map(({ _sortKey, ...rest }) => rest);
  renderMatches(matches);
  setMeta(
    `Mock: ${matches.length} oneri (currentUser: ${email || "-"}). Senaryo: Ali -> CRM/Gorev; Ayse -> Makale/Ozet/NLP basliklari one alinir.`
  );
}

function renderMatches(matches) {
  const area = document.getElementById("matchResultArea");
  if (!area) return;

  if (!matches || matches.length === 0) {
    area.innerHTML = `
      <div class="match-empty-state">
        <div class="radar-icon" aria-hidden="true">
          <span class="radar-ring ring-1"></span>
          <span class="radar-ring ring-2"></span>
          <span class="radar-ring ring-3"></span>
          <span class="radar-dot"></span>
        </div>
        <p>Su an icin yetkinliklerine uygun yeni bir proje bulunamadi. Profilinde yetkinlik / biyografi ekleyip tekrar dene.</p>
      </div>
    `;
    return;
  }

  area.innerHTML = `
    <div class="feed-grid">
      ${matches
        .map((match) => {
          const percent = resolveSimilarityPercent(match);
          const tierClass = tierClassForPercent(percent);
          const title = match.project_title || `Proje #${match.project_id || "-"}`;
          const pid = match.project_id ? `ilan-detay.html?id=${encodeURIComponent(String(match.project_id))}` : "ilan-detay.html";
          const required = match.required_skills || [];
          const commonList = Array.isArray(match.common_skills) ? match.common_skills : [];
          const commonSet = new Set(commonList.map((c) => String(c).trim().toLowerCase()).filter(Boolean));
          const summary = match.match_summary || "Profilin ve ilan gereksinimleri karsilastirildi.";
          const tagsHtml = renderRequiredSkillTags(required, commonSet);

          return `
            <article class="job-card project-card match-card">
              <div class="job-card-head match-card-head">
                <div class="author">
                  <div class="avatar">AI</div>
                  <div>
                    <div class="author-name">Milvus / AI Eslestirme</div>
                    <div class="author-role">${escapeHtml(match.suggestion_status || "suggested")}</div>
                  </div>
                </div>
                <span class="match-score-badge ${tierClass}">%${percent} Eslesme</span>
              </div>
              <h3 class="job-title">${escapeHtml(title)}</h3>
              <div class="job-meta-row">
                <span class="chip">Ham skor: ${escapeHtml(String(match.score ?? "-"))}</span>
                <span class="chip">Gerekli: ${required.length}</span>
              </div>
              <div class="match-skill-block">
                <span class="match-skill-label">Ilan gereksinimleri</span>
                <div class="tags">${tagsHtml}</div>
              </div>
              <p class="match-ai-blurb">${escapeHtml(summary)}</p>
              <div class="match-card-actions">
                <a class="btn btn-ghost" href="${pid}">Detaylari Incele</a>
                <a class="btn btn-primary" href="${pid}">Eslesme Istegi Gonder</a>
              </div>
            </article>
          `;
        })
        .join("")}
    </div>
  `;
}

async function loadMatchSuggestions() {
  showSkeleton();
  setMeta("AI profilini ve teknik yetkinliklerini tarayarak eslesmeleri hazirliyor...");

  if (typeof authIsMockSession === "function" && authIsMockSession()) {
    await loadMockMatchSuggestions();
    return;
  }

  try {
    const postResp = await fetch(`${authGetApiBase()}/me/match-suggestions/`, {
      method: "POST",
      headers: authHeaders(true),
      body: JSON.stringify({ top_k: 12, max_tags: 24 }),
    });
    const raw = await postResp.text();
    let data = {};
    try {
      data = raw ? JSON.parse(raw) : {};
    } catch (_e) {
      data = {};
    }

    if (!postResp.ok) {
      const msg =
        typeof authSummarizeApiError === "function"
          ? authSummarizeApiError(data)
          : data.detail || `HTTP ${postResp.status}`;
      throw new Error(msg || "Eslestirme basarisiz");
    }

    let matches = data.matches || [];
    const source = data.source || "milvus";

    if (!matches.length) {
      const getResp = await fetch(`${authGetApiBase()}/me/match-suggestions/?top_k=12`, {
        method: "GET",
        headers: authHeaders(),
      });
      const rawGet = await getResp.text();
      try {
        const d2 = rawGet ? JSON.parse(rawGet) : {};
        if (getResp.ok && Array.isArray(d2.matches)) matches = d2.matches;
      } catch (_e) {
        /* ignore */
      }
    }

    renderMatches(matches);
    setMeta(
      `Toplam ${matches.length} proje onerildi (kaynak: ${source}). Sunucu: unvan + bio + yetkinlik etiketleri birlestirilerek kullaniciya ozel vektor sorgusu.`
    );
  } catch (error) {
    console.warn("[matchmaking]", error);
    renderMatches([]);
    setMeta(error.message || "Eslesme sonuclari su an yuklenemedi.");
  }
}

window.addEventListener("DOMContentLoaded", () => {
  if (!requireAuth()) return;
  coforgeInitTheme();
  initGlobalBackgroundSpotlight();
  initProfileMenu();
  coforgeInitHeaderAvatar();
  document.getElementById("btnLogoutMenu")?.addEventListener("click", () => {
    authClearSession();
    window.location.href = "login.html";
  });
  loadMatchSuggestions();
});
