import React from "react";
import {createRoot} from "react-dom/client";
import {AgentApp} from "./components/AgentApp";
import {syncWulinTheme} from "./syncWulinTheme";
import "./styles/agent_panel.css";

function mountRoot() {
  let el = document.getElementById("wulin-agent-root");
  if (!el) {
    el = document.createElement("div");
    el.id = "wulin-agent-root";
    document.body.appendChild(el);
  }
  syncWulinTheme(el);
  createRoot(el).render(<AgentApp />);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mountRoot);
} else {
  mountRoot();
}
