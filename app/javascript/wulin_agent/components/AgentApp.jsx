import {useCallback, useState} from "react";
import {WulinAgentProvider} from "./WulinAgentProvider";
import {Thread} from "./Thread";
import {ConversationHistory} from "./ConversationHistory";
import {ApprovalModeSelect} from "./ApprovalModeSelect";
import {
  getConversationId,
  getStoredApprovalMode,
  setPendingApprovalMode,
  updateApprovalMode,
} from "../api";

export function AgentApp() {
  const [open, setOpen] = useState(false);
  const [approvalMode, setApprovalMode] = useState(
    () => getStoredApprovalMode() ?? "confirm_writes"
  );

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

  return (
    <WulinAgentProvider>
      <button
        type="button"
        className="wulin-agent-toggle"
        aria-expanded={open}
        aria-label={open ? "Fermer l'agent" : "Ouvrir l'agent"}
        onClick={() => setOpen((v) => !v)}
      >
        <i className="material-icons" aria-hidden="true">
          smart_toy
        </i>
        <span className="wulin-agent-toggle__label">Agent</span>
      </button>

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
        aria-hidden={!open}
      >
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
            <ApprovalModeSelect
              value={approvalMode}
              onChange={handleApprovalModeChange}
            />
          </header>
          <ConversationHistory
            onApprovalModeChange={handleConversationApprovalMode}
          />
          <Thread />
        </div>
      </aside>
    </WulinAgentProvider>
  );
}
