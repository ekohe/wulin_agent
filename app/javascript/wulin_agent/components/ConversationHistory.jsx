import { useEffect, useState } from "react";
import { useAui } from "@assistant-ui/react";
import { fetchConversation, listConversations, setConversationId, resetConversationId } from "../api";
import { toAssistantUiMessages } from "../messageMapper";

export function ConversationHistory() {
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

  async function handleClick(id) {
    setSelectedId(id);
    const data = await fetchConversation(id);
    setConversationId(data.id);
    aui.thread().reset(toAssistantUiMessages(data.messages));
  }

  async function startNew() {
    resetConversationId()
    setSelectedId(null)
    aui.thread().reset([])
  }


  if (loading) return <p style={{ padding: 8 }}>Loading conversations...</p>;

  return (
    <div style={{ padding: "8px", borderBottom: "1px solid #eee", background: "#fafafa" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
        <strong>History ({items.length})</strong>
        <button type="button" onClick={startNew}>
            + New Conversation
        </button>
      </div>
      <ul>
        {items.map((item) => (
          <li key={item.id}>
            <button type="button" onClick={() => handleClick(item.id)}>
              {item.title}
            </button>
          </li>
        ))}
      </ul>
      {selectedId && <p>Selected : #{selectedId}</p>}
    </div>
  );
}