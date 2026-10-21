import {useCallback, useEffect, useRef, useState} from "react";
import {createPortal} from "react-dom";
import {WulinAgentProvider} from "./WulinAgentProvider";
import {Thread} from "./Thread";
import {ConversationHistory} from "./ConversationHistory";
import {ApprovalModeSelect} from "./ApprovalModeSelect";
import {McpTokenManager} from "./McpTokenManager";
import {IconButton} from "./IconButton";
import {strings} from "../strings";
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

export function AgentApp({fullPage = false}) {
  const [open, setOpen] = useState(false);
  const [toggleSlot, setToggleSlot] = useState(null);
  const [model, setModel] = useState(null);
  const [toolbarEnabled, setToolbarEnabled] = useState(false);
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
  const [awaitingApproval, setAwaitingApproval] = useState(false);
  const [shellError, setShellError] = useState("");
  const panelRef = useRef(null);
  const toggleRef = useRef(null);
  const drawerWasOpen = useRef(false);
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
        historyMaxWidth(fullPage ? panelRef.current.clientWidth : drawerWidthRef.current),
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
  }, [fullPage]);

  useEffect(() => {
    const onWindowResize = () => {
      setDrawerWidth((current) =>
        Math.min(viewportMaxWidth(), Math.max(DRAWER_MIN_WIDTH, current))
      );
      setHistoryWidth((current) => {
        const max = historyMaxWidth(fullPage ? panelRef.current.clientWidth : drawerWidthRef.current);
        return Math.min(max, Math.max(HISTORY_MIN_WIDTH, current));
      });
    };

    onWindowResize();
    window.addEventListener("resize", onWindowResize);
    return () => window.removeEventListener("resize", onWindowResize);
  }, [fullPage]);

  useEffect(() => {
    if (!toolbarEnabled) return;
    const ul = document.querySelector("nav .nav-wrapper ul.right");
    if (!ul) return;

    const li = document.createElement("li");
    li.className = "wulin-agent-toggle-slot";
    ul.insertBefore(li, ul.firstChild);
    setToggleSlot(li);

    return () => {
      li.remove();
      setToggleSlot(null);
    };
  }, [toolbarEnabled]);

  useEffect(() => {
    fetchAgentConfig()
      .then((data) => {
        setModel(data.model);
        setToolbarEnabled(data.toolbar_enabled !== false);
      })
      .catch((err) => {
        console.error(err);
        setShellError(strings.configFailed);
      });
  }, []);

  useEffect(() => {
    setOpen(false);
  }, [fullPage]);

  useEffect(() => {
    if (fullPage || !open) return undefined;

    const onKey = (event) => {
      if (event.key !== "Escape") return;
      if (event.target?.closest?.("dialog")) return;
      const inDrawer =
        panelRef.current?.contains(event.target) || event.target === toggleRef.current;
      if (!inDrawer) return;
      setOpen(false);
    };

    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [fullPage, open]);

  useEffect(() => {
    // React 18 drops a boolean inert prop, so set the property directly. The
    // same aside becomes the full page during menu navigation, so clear it too.
    if (panelRef.current) panelRef.current.inert = !fullPage && !open;
  }, [fullPage, open]);

  useEffect(() => {
    if (fullPage) return;
    if (open) {
      drawerWasOpen.current = true;
      return;
    }
    if (!drawerWasOpen.current) return;
    drawerWasOpen.current = false;
    toggleRef.current?.focus();
  }, [fullPage, open]);

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
      setShellError(strings.approvalModeFailed);
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
      ref={toggleRef}
      className={`wulin-agent-toggle${fullPage || open ? " wulin-agent-toggle--open" : ""}`}
      aria-expanded={fullPage || open}
      aria-label={fullPage ? strings.focusAgent : open ? strings.closeAgent : strings.openAgent}
      onClick={() => {
        if (fullPage) {
          panelRef.current.querySelector(".wulin-agent-composer__input")?.focus();
        } else {
          setOpen((v) => !v);
        }
      }}
    >
      {/* An <i>, unlike the panel icons: wulin_master sizes span.material-icons inside nav. */}
      <i className="material-icons wulin-agent-cognition" aria-hidden="true">
        cognition
      </i>
    </button>
  );

  return (
    <WulinAgentProvider>
      {toolbarEnabled && toggleSlot && createPortal(toggleButton, toggleSlot)}

      {!fullPage && open && (
        <button
          type="button"
          className="wulin-agent-backdrop"
          aria-label={strings.close}
          onClick={() => setOpen(false)}
        />
      )}

      <aside
        ref={panelRef}
        className={fullPage ? "wulin-agent-page" : `wulin-agent-drawer${open ? " wulin-agent-drawer--open" : ""}`}
        style={fullPage ? undefined : {width: drawerWidth}}
        aria-hidden={!fullPage && !open}
      >
        {!fullPage && <div
          className="wulin-agent-drawer__resize"
          role="separator"
          aria-orientation="vertical"
          aria-label={strings.resizePanel}
          onMouseDown={handleDrawerResizeStart}
        />}
        <div className="wulin-agent-panel">
          <header className="wulin-agent-panel__header">
            <div className="wulin-agent-panel__header-row">
              <div className="wulin-agent-panel__heading">
                <h2 className="wulin-agent-panel__title">{strings.panelTitle}</h2>
                {awaitingApproval && (
                  <span className="wulin-agent-panel__status">{strings.awaitingApproval}</span>
                )}
              </div>
              <div className="wulin-agent-panel__actions">
                {(fullPage || open) && <McpTokenManager />}
                {!fullPage && (
                  <IconButton icon="close" label={strings.close} onClick={() => setOpen(false)} />
                )}
              </div>
            </div>
            <div className="wulin-agent-panel__meta">
              {model && (
                <>
                  <span className="wulin-agent-panel__model-label">{strings.modelLabel}</span>
                  <span className="wulin-agent-panel__model">{model}</span>
                </>
              )}
              <span className="wulin-agent-panel__model-label wulin-agent-panel__approval-label">
                {strings.approvalModeLabel}
              </span>
              <ApprovalModeSelect
                value={approvalMode}
                onChange={handleApprovalModeChange}
              />
            </div>
            {shellError && (
              <p className="wulin-agent-panel__notice" role="alert">{shellError}</p>
            )}
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
              onAwaitingApprovalChange={setAwaitingApproval}
            />
            <Thread conversationStatus={conversationStatus} />
          </div>
        </div>
      </aside>
    </WulinAgentProvider>
  );
}
