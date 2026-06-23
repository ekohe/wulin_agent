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

export function ConversationHistory({onApprovalModeChange}) {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState(null);
  const aui = useAui();


  useEffect(() => {
    listConversations()
      .then(setItems)
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

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

  if (loading) {
    return (
      <div className="wulin-agent-history">
        <p className="wulin-agent-history__status">Loading…</p>
      </div>
    );
  }

  return (
    <div className="wulin-agent-history">
      <div className="wulin-agent-history__header">
        <span className="wulin-agent-history__title">History ({items.length})</span>
        <button
          type="button"
          className="wulin-agent-history__new"
          onClick={startNew}
        >
          + New
        </button>
      </div>
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
    </div>
  );
}