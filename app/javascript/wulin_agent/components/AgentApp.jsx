import {useState} from "react";
import {WulinAgentProvider} from "./WulinAgentProvider";
import {Thread} from "./Thread";
import { ConversationHistory } from "./ConversationHistory";

export function AgentApp() {
  const [open, setOpen] = useState(false);

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
            <h2 className="wulin-agent-panel__title">Wulin Agent</h2>
            <button
              type="button"
              className="wulin-agent-panel__close"
              aria-label="Fermer"
              onClick={() => setOpen(false)}
            >
              ×
            </button>
          </header>
          <ConversationHistory />
          <Thread />
        </div>
      </aside>
    </WulinAgentProvider>
  );
}
