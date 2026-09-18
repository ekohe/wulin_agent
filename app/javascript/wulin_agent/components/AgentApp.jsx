import {useCallback, useEffect, useRef, useState} from "react";
import {createPortal} from "react-dom";
import {WulinAgentProvider} from "./WulinAgentProvider";
import {Thread} from "./Thread";
import {ConversationHistory} from "./ConversationHistory";
import {ApprovalModeSelect} from "./ApprovalModeSelect";
import {
  getConversationId,
  getStoredApprovalMode,
  setOnConversationCreated,
  setPendingApprovalMode,
  updateApprovalMode,
  fetchAgentConfig
} from "../api";

const DRAWER_MIN_WIDTH = 360;
const DRAWER_DEFAULT_WIDTH = 480;
const DRAWER_WIDTH_KEY = "wulin_agent_drawer_width";
const HISTORY_MIN_WIDTH = 120;
const HISTORY_DEFAULT_WIDTH = 200;
const HISTORY_WIDTH_KEY = "wulin_agent_history_width";
const SIZE_FRACTION = 2 / 3;

function viewportMaxWidth() {
  return Math.floor(window.innerWidth * SIZE_FRACTION);
}

function historyMaxWidth(drawerWidth) {
  return Math.floor(drawerWidth * SIZE_FRACTION);
}

function getStoredDrawerWidth() {
  const stored = parseInt(localStorage.getItem(DRAWER_WIDTH_KEY), 10);
  const width = Number.isFinite(stored) ? stored : DRAWER_DEFAULT_WIDTH;
  return Math.min(viewportMaxWidth(), Math.max(DRAWER_MIN_WIDTH, width));
}

function getStoredHistoryWidth(drawerWidth) {
  const stored = parseInt(localStorage.getItem(HISTORY_WIDTH_KEY), 10);
  const width = Number.isFinite(stored) ? stored : HISTORY_DEFAULT_WIDTH;
  return Math.min(historyMaxWidth(drawerWidth), Math.max(HISTORY_MIN_WIDTH, width));
}

export function AgentApp() {
  const [open, setOpen] = useState(false);
  const [toggleSlot, setToggleSlot] = useState(null);
  const [model, setModel] = useState(null);
  const [historyVersion, setHistoryVersion] = useState(0);
  const [historyOpen, setHistoryOpen] = useState(true);
  const [approvalMode, setApprovalMode] = useState(
    () => getStoredApprovalMode() ?? "confirm_writes"
  );
  const [drawerWidth, setDrawerWidth] = useState(getStoredDrawerWidth);
  const [historyWidth, setHistoryWidth] = useState(() =>
    getStoredHistoryWidth(getStoredDrawerWidth())
  );
  const [conversationStatus, setConversationStatus] = useState("idle");
  const drawerWidthRef = useRef(drawerWidth);
  const historyWidthRef = useRef(historyWidth);
  drawerWidthRef.current = drawerWidth;
  historyWidthRef.current = historyWidth;

  const handleDrawerResizeStart = useCallback((event) => {
    event.preventDefault();
    const startX = event.clientX;
    const startWidth = drawerWidthRef.current;
    let latestDrawer = startWidth;
    let latestHistory = historyWidthRef.current;

    const onMove = (moveEvent) => {
      latestDrawer = Math.min(
        viewportMaxWidth(),
        Math.max(DRAWER_MIN_WIDTH, startWidth + (startX - moveEvent.clientX))
      );
      latestHistory = Math.min(
        historyMaxWidth(latestDrawer),
        Math.max(HISTORY_MIN_WIDTH, latestHistory)
      );
      setDrawerWidth(latestDrawer);
      setHistoryWidth(latestHistory);
    };

    const onUp = () => {
      localStorage.setItem(DRAWER_WIDTH_KEY, String(latestDrawer));
      localStorage.setItem(HISTORY_WIDTH_KEY, String(latestHistory));
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

  const handleHistoryResizeStart = useCallback((event) => {
    event.preventDefault();
    const startX = event.clientX;
    const startWidth = historyWidthRef.current;
    let latestHistory = startWidth;

    const onMove = (moveEvent) => {
      latestHistory = Math.min(
        historyMaxWidth(drawerWidthRef.current),
        Math.max(HISTORY_MIN_WIDTH, startWidth + (moveEvent.clientX - startX))
      );
      setHistoryWidth(latestHistory);
    };

    const onUp = () => {
      localStorage.setItem(HISTORY_WIDTH_KEY, String(latestHistory));
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
    const onWindowResize = () => {
      setDrawerWidth((current) =>
        Math.min(viewportMaxWidth(), Math.max(DRAWER_MIN_WIDTH, current))
      );
      setHistoryWidth((current) => {
        const max = historyMaxWidth(drawerWidthRef.current);
        return Math.min(max, Math.max(HISTORY_MIN_WIDTH, current));
      });
    };

    window.addEventListener("resize", onWindowResize);
    return () => window.removeEventListener("resize", onWindowResize);
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

  const refreshHistory = useCallback(() => {
    setHistoryVersion((v) => v + 1);
  }, []);

  useEffect(() => {
    setOnConversationCreated(refreshHistory);
    return () => setOnConversationCreated(null);
  }, [refreshHistory]);

  const toggleButton = (
    <button
      type="button"
      className={`wulin-agent-toggle${open ? " wulin-agent-toggle--open" : ""}`}
      aria-expanded={open}
      aria-label={open ? "Close agent" : "Open agent"}
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
          aria-label="Close"
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
          aria-label="Resize panel"
          onMouseDown={handleDrawerResizeStart}
        />
        <div className="wulin-agent-panel">
          <header className="wulin-agent-panel__header">
            <div className="wulin-agent-panel__header-row">
              <h2 className="wulin-agent-panel__title">Wulin Agent</h2>
              <button
                type="button"
                className="wulin-agent-panel__close"
                aria-label="Close"
                onClick={() => setOpen(false)}
              >
                ×
              </button>
            </div>
            <div className="wulin-agent-panel__meta">
              {model && (
                <>
                  <span className="wulin-agent-panel__model-label">Model</span>
                  <span className="wulin-agent-panel__model">{model}</span>
                </>
              )}
              <span className="wulin-agent-panel__model-label wulin-agent-panel__approval-label">
                Approval mode
              </span>
              <ApprovalModeSelect
                value={approvalMode}
                onChange={handleApprovalModeChange}
              />
            </div>
          </header>
          <div className="wulin-agent-body">
            <ConversationHistory
              open={historyOpen}
              width={historyWidth}
              historyVersion={historyVersion}
              onToggle={() => setHistoryOpen((v) => !v)}
              onResizeStart={handleHistoryResizeStart}
              onApprovalModeChange={handleConversationApprovalMode}
              onStatusChange={setConversationStatus}
            />
            <Thread conversationStatus={conversationStatus} />
          </div>
        </div>
      </aside>
    </WulinAgentProvider>
  );
}
