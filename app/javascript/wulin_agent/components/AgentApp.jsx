import {useCallback, useEffect, useRef, useState} from "react";
import {createPortal} from "react-dom";
import {WulinAgentProvider} from "./WulinAgentProvider";
import {Thread} from "./Thread";
import {ConversationHistory} from "./ConversationHistory";
import {ApprovalModeSelect} from "./ApprovalModeSelect";
import {
  getConversationId,
  getStoredApprovalMode,
  setPendingApprovalMode,
  updateApprovalMode,
  fetchAgentConfig
} from "../api";

const DRAWER_MIN_WIDTH = 360;
const DRAWER_DEFAULT_WIDTH = 480;
const DRAWER_WIDTH_KEY = "wulin_agent_drawer_width";

function getStoredDrawerWidth() {
  const stored = parseInt(localStorage.getItem(DRAWER_WIDTH_KEY), 10);
  if (!Number.isFinite(stored)) return DRAWER_DEFAULT_WIDTH;
  return Math.max(DRAWER_MIN_WIDTH, stored);
}

export function AgentApp() {
  const [open, setOpen] = useState(false);
  const [toggleSlot, setToggleSlot] = useState(null);
  const [model, setModel] = useState(null);
  const [historyOpen, setHistoryOpen] = useState(true);
  const [approvalMode, setApprovalMode] = useState(
    () => getStoredApprovalMode() ?? "confirm_writes"
  );
  const [drawerWidth, setDrawerWidth] = useState(getStoredDrawerWidth);
  const drawerWidthRef = useRef(drawerWidth);
  drawerWidthRef.current = drawerWidth;

  const handleResizeStart = useCallback((event) => {
    event.preventDefault();
    const startX = event.clientX;
    const startWidth = drawerWidthRef.current;

    const onMove = (moveEvent) => {
      const next = Math.min(
        window.innerWidth,
        Math.max(DRAWER_MIN_WIDTH, startWidth + (startX - moveEvent.clientX))
      );
      setDrawerWidth(next);
    };

    const onUp = () => {
      localStorage.setItem(DRAWER_WIDTH_KEY, String(drawerWidthRef.current));
      document.removeEventListener("mousemove", onMove);
      document.removeEventListener("mouseup", onUp);
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    };

    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
    document.addEventListener("mousemove", onMove);
    document.addEventListener("mouseup", onUp);
  }, []);

  useEffect(() => {
    const ul = document.querySelector("nav .nav-wrapper ul.right");
    if (!ul) return;

    const li = document.createElement("li");
    li.className = "wulin-agent-toggle-slot";
    ul.insertBefore(li, ul.firstChild);
    setToggleSlot(li);

    return () => li.remove();
  }, []);

  useEffect(() => {
    fetchAgentConfig()
      .then((data) => setModel(data.model))
      .catch((err) => console.error(err));
  }, []);

  const handleApprovalModeChange = useCallback(async (mode) => {
    setApprovalMode(mode);
    setPendingApprovalMode(mode);

    const id = getConversationId();
    if (id == null) return;

    try {
      const data = await updateApprovalMode(id, mode);
      setApprovalMode(data.approval_mode);
      setPendingApprovalMode(data.approval_mode);
    } catch (error) {
      console.error(error);
    }
  }, []);

  const handleConversationApprovalMode = useCallback((mode) => {
    setApprovalMode(mode);
    setPendingApprovalMode(mode);
  }, []);

  const toggleButton = (
    <button
      type="button"
      className={`wulin-agent-toggle${open ? " wulin-agent-toggle--open" : ""}`}
      aria-expanded={open}
      aria-label={open ? "Fermer l'agent" : "Ouvrir l'agent"}
      onClick={() => setOpen((v) => !v)}
    >
      <i className="material-icons" aria-hidden="true">
        android
      </i>
    </button>
  );

  return (
    <WulinAgentProvider>
      {toggleSlot && createPortal(toggleButton, toggleSlot)}

      {open && (
        <button
          type="button"
          className="wulin-agent-backdrop"
          aria-label="Fermer"
          onClick={() => setOpen(false)}
        />
      )}

      <aside
        className={`wulin-agent-drawer${open ? " wulin-agent-drawer--open" : ""}`}
        style={{width: drawerWidth}}
        aria-hidden={!open}
      >
        <div
          className="wulin-agent-drawer__resize"
          role="separator"
          aria-orientation="vertical"
          aria-label="Redimensionner le panneau"
          onMouseDown={handleResizeStart}
        />
        <div className="wulin-agent-panel">
          <header className="wulin-agent-panel__header">
            <div className="wulin-agent-panel__header-row">
              <h2 className="wulin-agent-panel__title">Wulin Agent</h2>
              <button
                type="button"
                className="wulin-agent-panel__close"
                aria-label="Fermer"
                onClick={() => setOpen(false)}
              >
                ×
              </button>
            </div>
            {model && (
              <div className="wulin-agent-panel__meta">
                <span className="wulin-agent-panel__model-label">Model</span>
                <span className="wulin-agent-panel__model">{model}</span>
              </div>
            )}
            <ApprovalModeSelect
              value={approvalMode}
              onChange={handleApprovalModeChange}
            />
          </header>
          <div className="wulin-agent-body">
            <ConversationHistory
              open={historyOpen}
              onToggle={() => setHistoryOpen((v) => !v)}
              onApprovalModeChange={handleConversationApprovalMode}
            />
            <Thread />
          </div>
        </div>
      </aside>
    </WulinAgentProvider>
  );
}
