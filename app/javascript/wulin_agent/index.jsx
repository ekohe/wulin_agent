import React from "react";
import {createRoot} from "react-dom/client";
import {AgentApp} from "./components/AgentApp";
import "./styles/agent_panel.css";

function mount() {
  const el = document.getElementById("wulin-agent-root");
  if (!el) return;
  createRoot(el).render(<AgentApp />);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mount);
} else {
  mount();
}
