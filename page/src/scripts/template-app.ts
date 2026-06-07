/**
 * Template App - Main client-side functionality
 * Handles filtering, searching, detail view, and navigation
 */

// Extend window for toast function
declare global {
  interface Window {
    showToast?: (message: string) => void;
  }
}

// Template data map for quick access
const templatesMap = new Map<string, Record<string, unknown>>();

// Helper: Create element with optional classes and text content
function createElement<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  options?: { className?: string; textContent?: string }
): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  if (options?.className) el.className = options.className;
  if (options?.textContent) el.textContent = options.textContent;
  return el;
}

// Helper: Clear element and append children
function replaceChildren(parent: Element, ...children: Node[]): void {
  parent.replaceChildren(...children);
}

// Helper: Create text node
function text(content: string): Text {
  return document.createTextNode(content);
}

// Extract only the latest version from changelog
function extractLatestChangelog(changelog: string): string {
  const versionRegex = /^## \[[\d.]+-?\d*\]/m;
  const lines = changelog.split('\n');
  const result: string[] = [];
  let foundFirst = false;

  for (const line of lines) {
    if (versionRegex.test(line)) {
      if (foundFirst) break;
      foundFirst = true;
    }
    if (foundFirst) {
      result.push(line);
    }
  }

  return result.join('\n').trim() || changelog;
}

// Show template detail
function showTemplateDetail(data: Record<string, unknown>): void {
  populateDetail(data);

  document.getElementById("template-list")?.classList.add("hidden");
  document.getElementById("template-detail")?.classList.remove("hidden");

  const url = new URL(location.href);
  url.searchParams.set("template", data.name as string);
  url.searchParams.delete("q");
  url.searchParams.delete("category");
  history.pushState({ template: data.name }, "", url);

  window.scrollTo({ top: 0, behavior: "smooth" });
}

// Hide template detail
function hideTemplateDetail(): void {
  document.getElementById("template-detail")?.classList.add("hidden");
  document.getElementById("template-list")?.classList.remove("hidden");

  const url = new URL(location.href);
  url.searchParams.delete("template");
  history.pushState({}, "", url);
}

// Populate detail with template data
function populateDetail(data: Record<string, unknown>): void {
  const iconUrlSvg = `https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/svg/${data.icon}.svg`;
  const iconUrlPng = `https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons@main/png/${data.icon}.png`;
  const displayName = (data.name as string).charAt(0).toUpperCase() + (data.name as string).slice(1);

  // Icon & Name (with SVG -> PNG fallback)
  const iconEl = document.getElementById("detail-icon") as HTMLImageElement | null;
  if (iconEl) {
    iconEl.src = iconUrlSvg;
    iconEl.onerror = () => {
      iconEl.onerror = null;
      iconEl.src = iconUrlPng;
    };
  }
  const nameEl = document.getElementById("detail-name");
  if (nameEl) nameEl.textContent = displayName;

  // Description
  const descEl = document.getElementById("detail-description");
  if (descEl) descEl.textContent = data.description as string;

  // Badges
  const badgesEl = document.getElementById("detail-badges");
  if (badgesEl) {
    const versionBadge = createElement("span", {
      className: "badge badge-success",
      textContent: `v${data.version}-${data.build_version}`
    });
    const osTag = createElement("span", {
      className: "tag",
      textContent: data.base_os as string
    });
    const categoryBadge = createElement("span", {
      className: "badge badge-info",
      textContent: data.category as string
    });
    replaceChildren(badgesEl, versionBadge, osTag, categoryBadge);
  }

  // Project URL
  const projectUrlEl = document.getElementById("detail-project-url") as HTMLAnchorElement | null;
  if (projectUrlEl) {
    if (data.project_url) {
      projectUrlEl.href = data.project_url as string;
      projectUrlEl.classList.remove("hidden");
    } else {
      projectUrlEl.classList.add("hidden");
    }
  }

  // Download
  const downloadSection = document.getElementById("detail-download-section");
  const wgetEl = document.getElementById("detail-wget") as HTMLInputElement | null;
  const sha512El = document.getElementById("detail-sha512");

  if (data.download_url) {
    downloadSection?.classList.remove("hidden");
    if (wgetEl) {
      wgetEl.value = `URL: ${data.download_url}`;
      wgetEl.setAttribute("data-url", data.download_url as string);
    }
    const sha512Wrapper = document.getElementById("detail-sha512-wrapper");
    if (sha512El && sha512Wrapper) {
      if (data.sha512) {
        (sha512El as HTMLInputElement).value = `SHA512: ${data.sha512}`;
        sha512El.setAttribute("data-sha512", data.sha512 as string);
        sha512Wrapper.classList.remove("hidden");
      } else {
        (sha512El as HTMLInputElement).value = "";
        sha512Wrapper.classList.add("hidden");
      }
    }
  } else {
    downloadSection?.classList.add("hidden");
  }

  // Quick Start
  const qsSection = document.getElementById("detail-quickstart-section");
  const qsEl = document.getElementById("detail-quickstart");
  if (data.quick_start && qsSection && qsEl) {
    qsSection.classList.remove("hidden");
    const pre = createElement("pre");
    const code = createElement("code", { textContent: data.quick_start as string });
    pre.appendChild(code);
    replaceChildren(qsEl, pre);
  } else {
    qsSection?.classList.add("hidden");
  }

  // Resources
  const resourcesEl = document.getElementById("detail-resources");
  const resources = data.resources as Record<string, unknown> | undefined;
  if (resourcesEl && resources) {
    const memRec = resources.memory_recommended as number;
    const memMin = resources.memory_min as number;
    const formatMem = (mb: number): string => mb >= 1024 ? `${mb / 1024}GB` : `${mb}MB`;

    const createStat = (value: string, label: string, desc?: string): HTMLDivElement => {
      const stat = createElement("div", { className: "stat" });
      stat.appendChild(createElement("div", { className: "stat-value", textContent: value }));
      stat.appendChild(createElement("div", { className: "stat-label", textContent: label }));
      if (desc) stat.appendChild(createElement("div", { className: "stat-desc", textContent: desc }));
      return stat;
    };

    replaceChildren(
      resourcesEl,
      createStat(formatMem(memRec), "Memory", `min: ${formatMem(memMin)}`),
      createStat(resources.disk_recommended as string, "Disk", `min: ${resources.disk_min}`),
      createStat(String(resources.cores), (resources.cores as number) === 1 ? "Core" : "Cores")
    );
  }

  // Ports
  const portsSection = document.getElementById("detail-ports-section");
  const portsEl = document.getElementById("detail-ports");
  const ports = data.ports as Array<{port: number; description: string}> | undefined;
  if (ports?.length && portsSection && portsEl) {
    portsSection.classList.remove("hidden");
    const rows = ports.map(p => {
      const tr = createElement("tr");
      tr.appendChild(createElement("td", { className: "font-mono", textContent: String(p.port) }));
      tr.appendChild(createElement("td", { textContent: p.description }));
      return tr;
    });
    replaceChildren(portsEl, ...rows);
  } else {
    portsSection?.classList.add("hidden");
  }

  // Paths
  const pathsSection = document.getElementById("detail-paths-section");
  const pathsEl = document.getElementById("detail-paths");
  const paths = data.paths as Array<{path: string; description: string}> | undefined;
  if (paths?.length && pathsSection && pathsEl) {
    pathsSection.classList.remove("hidden");
    const rows = paths.map(p => {
      const tr = createElement("tr");
      tr.appendChild(createElement("td", { className: "font-mono text-xs", textContent: p.path }));
      tr.appendChild(createElement("td", { textContent: p.description }));
      return tr;
    });
    replaceChildren(pathsEl, ...rows);
  } else {
    pathsSection?.classList.add("hidden");
  }

  // User/Group IDs
  const userSection = document.getElementById("detail-user-section");
  const userEl = document.getElementById("detail-user");
  const user = data.user as {uid?: number; gid?: number} | undefined;
  if (user && (user.uid || user.gid) && userSection && userEl) {
    userSection.classList.remove("hidden");
    const rows: HTMLTableRowElement[] = [];
    if (user.uid) {
      const tr = createElement("tr");
      tr.appendChild(createElement("td", { textContent: "UID" }));
      tr.appendChild(createElement("td", { className: "font-mono", textContent: String(user.uid) }));
      rows.push(tr);
    }
    if (user.gid) {
      const tr = createElement("tr");
      tr.appendChild(createElement("td", { textContent: "GID" }));
      tr.appendChild(createElement("td", { className: "font-mono", textContent: String(user.gid) }));
      rows.push(tr);
    }
    replaceChildren(userEl, ...rows);
  } else {
    userSection?.classList.add("hidden");
  }

  // Credentials
  const credsSection = document.getElementById("detail-credentials-section");
  const credsEl = document.getElementById("detail-credentials");
  const credentials = data.credentials as {username: string; password: string; note?: string} | undefined;
  if (credentials && credsSection && credsEl) {
    credsSection.classList.remove("hidden");
    const fragment = document.createDocumentFragment();
    fragment.appendChild(text("User: "));
    fragment.appendChild(createElement("code", { textContent: credentials.username }));
    fragment.appendChild(text(" / Pass: "));
    fragment.appendChild(createElement("code", { textContent: credentials.password }));
    if (credentials.note) {
      fragment.appendChild(createElement("br"));
      fragment.appendChild(createElement("span", { className: "text-muted", textContent: credentials.note }));
    }
    replaceChildren(credsEl, fragment);
  } else {
    credsSection?.classList.add("hidden");
  }

  // FAQ
  const faqSection = document.getElementById("detail-faq-section");
  const faqEl = document.getElementById("detail-faq");
  const faq = data.faq as Array<{question: string; answer: string}> | undefined;
  if (faq?.length && faqSection && faqEl) {
    faqSection.classList.remove("hidden");

    const createChevronSvg = (): SVGSVGElement => {
      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.setAttribute("viewBox", "0 0 256 256");
      svg.setAttribute("fill", "currentColor");
      const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
      path.setAttribute("d", "M213.66,101.66l-80,80a8,8,0,0,1-11.32,0l-80-80A8,8,0,0,1,53.66,90.34L128,164.69l74.34-74.35a8,8,0,0,1,11.32,11.32Z");
      svg.appendChild(path);
      return svg;
    };

    const items = faq.map((item, i) => {
      const accordionItem = createElement("div", { className: `accordion-item${i === 0 ? " open" : ""}` });
      const header = createElement("button", { className: "accordion-header" });
      header.appendChild(text(item.question));
      header.appendChild(createChevronSvg());
      header.addEventListener("click", () => accordionItem.classList.toggle("open"));

      const content = createElement("div", { className: "accordion-content" });
      content.appendChild(createElement("p", { textContent: item.answer }));

      accordionItem.appendChild(header);
      accordionItem.appendChild(content);
      return accordionItem;
    });

    replaceChildren(faqEl, ...items);
  } else {
    faqSection?.classList.add("hidden");
  }

  // Changelog
  const changelogSection = document.getElementById("detail-changelog-section");
  const changelogEl = document.getElementById("detail-changelog");
  const changelogItem = document.getElementById("changelog-item");
  if (data.changelog && changelogSection && changelogEl && changelogItem) {
    changelogSection.classList.remove("hidden");
    changelogItem.classList.remove("open");

    const fullChangelog = data.changelog as string;
    const latestVersion = extractLatestChangelog(fullChangelog);

    const p = createElement("p");
    const lines = latestVersion.split('\n');
    lines.forEach((line, i) => {
      p.appendChild(text(line));
      if (i < lines.length - 1) p.appendChild(createElement("br"));
    });
    replaceChildren(changelogEl, p);
  } else {
    changelogSection?.classList.add("hidden");
  }

  // Release Info
  const releaseSection = document.getElementById("detail-release-section");
  const releaseDateEl = document.getElementById("detail-release-date");
  const githubLinkEl = document.getElementById("detail-github-link") as HTMLAnchorElement | null;

  if (data.release_url || data.release_date) {
    releaseSection?.classList.remove("hidden");
    if (data.release_date && releaseDateEl) {
      releaseDateEl.textContent = `Released: ${new Date(data.release_date as string).toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
        day: "numeric",
      })}`;
    }
    if (data.release_url && githubLinkEl) {
      githubLinkEl.href = data.release_url as string;
    }
  } else {
    releaseSection?.classList.add("hidden");
  }
}

// Initialize main app functionality
function initApp(): void {
  const searchInput = document.getElementById("search-input") as HTMLInputElement | null;
  const grid = document.getElementById("template-grid");
  const noResults = document.getElementById("no-results");
  const cards = grid?.querySelectorAll(".app-card");
  const pillButtons = document.querySelectorAll("#category-pills .pill");
  const sidebarButtons = document.querySelectorAll(".sidebar-nav button[data-category]");
  const visibleCountEl = document.getElementById("visible-count");

  if (!grid || !cards) return;

  let currentCategory = "all";
  let currentQuery = "";

  // Build templates map
  templatesMap.clear();
  cards.forEach((card) => {
    const dataStr = card.getAttribute("data-template");
    if (dataStr) {
      try {
        const data = JSON.parse(dataStr);
        templatesMap.set(data.name, data);
      } catch {
        // Invalid JSON, skip
      }
    }
  });

  // Get query from URL
  const urlParams = new URLSearchParams(window.location.search);
  const initialQuery = urlParams.get("q") || "";
  const initialCategory = urlParams.get("category") || "all";

  if (initialQuery && searchInput) {
    searchInput.value = initialQuery;
    currentQuery = initialQuery.toLowerCase();
  }
  currentCategory = initialCategory;

  function updateCategoryUI(): void {
    pillButtons.forEach((btn) => {
      const cat = btn.getAttribute("data-category");
      btn.classList.toggle("active", cat === currentCategory);
    });

    sidebarButtons.forEach((btn) => {
      const cat = btn.getAttribute("data-category");
      btn.classList.toggle("active", cat === currentCategory);
    });
  }

  function applyFilters(): void {
    let visibleCount = 0;

    cards.forEach((card) => {
      const name = card.getAttribute("data-name") || "";
      const description = card.getAttribute("data-description") || "";
      const category = card.getAttribute("data-category") || "";

      const matchesSearch = !currentQuery ||
        name.includes(currentQuery) ||
        description.includes(currentQuery);

      const matchesCategory = currentCategory === "all" || category === currentCategory;

      const isVisible = matchesSearch && matchesCategory;
      (card as HTMLElement).style.display = isVisible ? "" : "none";

      if (isVisible) visibleCount++;
    });

    if (visibleCountEl) {
      visibleCountEl.textContent = String(visibleCount);
    }

    noResults?.classList.toggle("hidden", visibleCount > 0);
    grid?.classList.toggle("hidden", visibleCount === 0 && cards.length > 0);
  }

  // Search input handler (debounced)
  let timeout: ReturnType<typeof setTimeout>;
  searchInput?.addEventListener("input", () => {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      currentQuery = searchInput.value.toLowerCase();

      if (!document.getElementById("template-detail")?.classList.contains("hidden")) {
        hideTemplateDetail();
      }

      applyFilters();

      const url = new URL(window.location.href);
      if (currentQuery) {
        url.searchParams.set("q", searchInput.value);
      } else {
        url.searchParams.delete("q");
      }
      history.replaceState(null, "", url.toString());
    }, 150);
  });

  // Category click handler
  function handleCategoryClick(category: string): void {
    currentCategory = category;

    if (!document.getElementById("template-detail")?.classList.contains("hidden")) {
      hideTemplateDetail();
    }

    updateCategoryUI();
    applyFilters();

    const url = new URL(window.location.href);
    if (currentCategory !== "all") {
      url.searchParams.set("category", currentCategory);
    } else {
      url.searchParams.delete("category");
    }
    history.replaceState(null, "", url.toString());
  }

  pillButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      handleCategoryClick(btn.getAttribute("data-category") || "all");
    });
  });

  sidebarButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      handleCategoryClick(btn.getAttribute("data-category") || "all");
      document.querySelector(".sidebar")?.classList.remove("open");
      document.getElementById("sidebar-overlay")?.classList.remove("open");
    });
  });

  updateCategoryUI();
  applyFilters();
}

// Initialize detail handlers
function initDetail(): void {
  const grid = document.getElementById("template-grid");
  const cards = grid?.querySelectorAll(".app-card");
  const backBtn = document.getElementById("back-to-list");
  const wgetCopyBtn = document.getElementById("detail-wget-copy");
  const wgetInput = document.getElementById("detail-wget") as HTMLInputElement | null;
  const sha512CopyBtn = document.getElementById("detail-sha512-copy");

  // Copy URL
  wgetCopyBtn?.addEventListener("click", async () => {
    const url = wgetInput?.getAttribute("data-url");
    if (url) {
      try {
        await navigator.clipboard.writeText(url);
        window.showToast?.("URL copied to clipboard!");
      } catch {
        wgetInput?.select();
        document.execCommand("copy");
        window.showToast?.("Copied!");
      }
    }
  });

  // Copy SHA512
  sha512CopyBtn?.addEventListener("click", async () => {
    const sha512El = document.getElementById("detail-sha512");
    const sha512Value = sha512El?.getAttribute("data-sha512");
    if (sha512Value) {
      try {
        await navigator.clipboard.writeText(sha512Value);
        window.showToast?.("SHA512 copied to clipboard!");
      } catch {
        window.showToast?.("Failed to copy");
      }
    }
  });

  // Changelog toggle
  const changelogToggle = document.getElementById("changelog-toggle");
  const changelogItem = document.getElementById("changelog-item");
  changelogToggle?.addEventListener("click", () => {
    changelogItem?.classList.toggle("open");
  });

  // Card click handler
  function handleCardClick(card: Element): void {
    const dataStr = card.getAttribute("data-template");
    if (dataStr) {
      try {
        const data = JSON.parse(dataStr);
        showTemplateDetail(data);
      } catch {
        // Invalid JSON
      }
    }
  }

  cards?.forEach((card) => {
    card.addEventListener("click", () => handleCardClick(card));
    card.addEventListener("keydown", (e: Event) => {
      const ke = e as KeyboardEvent;
      if (ke.key === "Enter" || ke.key === " ") {
        e.preventDefault();
        handleCardClick(card);
      }
    });
  });

  backBtn?.addEventListener("click", hideTemplateDetail);

  // Browser Back/Forward
  window.addEventListener("popstate", (e) => {
    const state = e.state as { template?: string } | null;
    if (state?.template) {
      const data = templatesMap.get(state.template);
      if (data) {
        populateDetail(data);
        document.getElementById("template-list")?.classList.add("hidden");
        document.getElementById("template-detail")?.classList.remove("hidden");
      }
    } else {
      document.getElementById("template-detail")?.classList.add("hidden");
      document.getElementById("template-list")?.classList.remove("hidden");
    }
  });

  // Deep-Link on page load
  const params = new URLSearchParams(location.search);
  const templateName = params.get("template");
  if (templateName) {
    const data = templatesMap.get(templateName);
    if (data) {
      populateDetail(data);
      document.getElementById("template-list")?.classList.add("hidden");
      document.getElementById("template-detail")?.classList.remove("hidden");
    }
  }
}

// Keyboard shortcuts
function initKeyboardShortcuts(): void {
  document.addEventListener("keydown", (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key === "k") {
      e.preventDefault();
      const searchInput = document.getElementById("search-input") as HTMLInputElement | null;
      searchInput?.focus();
    }
  });
}

// Initialize everything
export function init(): void {
  initApp();
  initDetail();
  initKeyboardShortcuts();
}

// Run on load
init();

// Re-init on Astro view transitions
document.addEventListener("astro:after-swap", init);
