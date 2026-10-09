import React from "react";
import {createRoot} from "react-dom/client";
import {AgentApp} from "./components/AgentApp";
import {syncWulinTheme} from "./syncWulinTheme";

function mountRoot() {
  let el = document.getElementById("wulin-agent-root");
  if (!el) {
    el = document.createElement("div");
    el.id = "wulin-agent-root";
    document.body.appendChild(el);
  }
  const root = createRoot(el);
  let currentPage;

  // Wulin Master replaces screen_content during menu navigation. Keep the
  // React root alive and move it between the page and the toolbar mount.
  function syncPage() {
    const page = document.getElementById("wulin-agent-page");
    if (page === currentPage) return;
    currentPage = page;
    (page || document.body).appendChild(el);
    if (page) document.title = page.dataset.title;
    syncWulinTheme(el);
    root.render(<AgentApp fullPage={Boolean(page)} />);
  }

  syncPage();
  new MutationObserver(syncPage).observe(document.body, {
    childList: true,
    subtree: true
  });
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mountRoot);
} else {
  mountRoot();
}
