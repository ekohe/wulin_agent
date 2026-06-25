import { useEffect, useState } from "react";
import { useAui } from "@assistant-ui/react";
import {
  fetchConversation,
  getStoredConversationId,
  listConversations,
  resetConversationId,
  setConversationId,
} from "../api";
import { toAssistantUiMessages } from "../messageMapper";

export function ConversationHistory({open, width, historyVersion, onToggle, onResizeStart, onApprovalModeChange}) {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState(null);
  const aui = useAui();

  const rootClass = open
    ? "wulin-agent-history"
    : "wulin-agent-history wulin-agent-history--collapsed";

  useEffect(() => {
    if (historyVersion === 0) setLoading(true);

    listConversations()
      .then(setItems)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [historyVersion]);

  useEffect(() => {
    if (historyVersion === 0) return;

    const storedId = getStoredConversationId();
    if (storedId) setSelectedId(storedId);
  }, [historyVersion]);

  useEffect(() => {
    const storedId = getStoredConversationId();
    if (!storedId) return;

    fetchConversation(storedId)
      .then((data) => {
        setSelectedId(data.id);
        setConversationId(data.id);
        onApprovalModeChange?.(data.approval_mode);
        aui.thread().reset(toAssistantUiMessages(data.messages));
      })
      .catch(() => {
        resetConversationId();
      });
  }, [aui, onApprovalModeChange]);

  async function handleClick(id) {
    setSelectedId(id);
    const data = await fetchConversation(id);
    setConversationId(data.id);
    onApprovalModeChange?.(data.approval_mode);
    aui.thread().reset(toAssistantUiMessages(data.messages));
  }

  function startNew() {
    resetConversationId();
    setSelectedId(null);
    aui.thread().reset([]);
  }

  return (
    <div className={rootClass} style={open ? {width} : undefined}>
      <div className="wulin-agent-history__header">
        <button
          type="button"
          className="wulin-agent-history__toggle"
          onClick={onToggle}
          aria-expanded={open}
          aria-label={open ? "Hide history" : "Show history"}
        >
          <i className="material-icons" aria-hidden="true">
            {open ? "chevron_left" : "chevron_right"}
          </i>
        </button>

        {open && !loading && (
          <>
            <span className="wulin-agent-history__title">
              History ({items.length})
            </span>
            <button
              type="button"
              className="wulin-agent-history__new"
              onClick={startNew}
            >
              + New
            </button>
          </>
        )}
      </div>

      {open && loading && (
        <p className="wulin-agent-history__status">Loading…</p>
      )}

      {open && !loading && (
        <ul className="wulin-agent-history__list">
          {items.map((item) => (
            <li key={item.id}>
              <button
                type="button"
                className={
                  selectedId === item.id
                    ? "wulin-agent-history__item wulin-agent-history__item--active"
                    : "wulin-agent-history__item"
                }
                onClick={() => handleClick(item.id)}
              >
                {item.title}
              </button>
            </li>
          ))}
        </ul>
      )}

      {open && (
        <div
          className="wulin-agent-history__resize"
          role="separator"
          aria-orientation="vertical"
          aria-label="Redimensionner l'historique"
          onMouseDown={onResizeStart}
        />
      )}
    </div>
  );
}
