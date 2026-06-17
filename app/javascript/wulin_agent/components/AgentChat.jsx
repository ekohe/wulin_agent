import {useRef, useState} from "react";
import {sendMessage} from "../api";
import {parseDataStream} from "../parseDataStream";

export function AgentChat() {
  const [input, setInput] = useState("");
  const [messages, setMessages] = useState([]);
  const [streaming, setStreaming] = useState(false);
  const [conversationId, setConversationId] = useState(null);
  const [error, setError] = useState(null);
  const abortRef = useRef(null);

  async function handleSubmit(e) {
    e.preventDefault();
    const text = input.trim();
    if (!text || streaming) return;

    setInput("");
    setError(null);
    setMessages((prev) => [...prev, {role: "user", content: text}]);
    setStreaming(true);
    abortRef.current = new AbortController();

    try {
      const {body, conversationId: id} = await sendMessage(
        text,
        conversationId,
        {signal: abortRef.current.signal}
      );

      if (id != null) setConversationId(String(id));

      setMessages((prev) => [...prev, {role: "assistant", content: ""}]);

      for await (const event of parseDataStream(body)) {
        if (event.type === "text_delta") {
          setMessages((prev) => {
            const copy = [...prev];
            const last = copy[copy.length - 1];
            copy[copy.length - 1] = {
              ...last,
              content: last.content + event.content,
            };
            return copy;
          });
        }
        if (event.type === "error") {
          throw new Error(event.message);
        }
      }
    } catch (err) {
      if (err.name !== "AbortError") {
        setError(err.message);
      }
    } finally {
      setStreaming(false);
    }
  }

  return (
    <div style={{maxWidth: 640, margin: "2rem auto", fontFamily: "system-ui"}}>
      <h2>Wulin Agent</h2>
      {conversationId && (
        <p style={{fontSize: 12, color: "#666"}}>
          Conversation #{conversationId}
        </p>
      )}
      {error && (
        <p style={{color: "crimson", fontSize: 14}}>{error}</p>
      )}
      <div
        style={{
          minHeight: 200,
          border: "1px solid #ccc",
          borderRadius: 8,
          padding: "1rem",
          marginBottom: "1rem",
          background: "#fafafa",
        }}
      >
        {messages.length === 0 && (
          <p style={{color: "#999"}}>Ask a question…</p>
        )}
        {messages.map((m, i) => (
          <p key={i} style={{margin: "0.5rem 0"}}>
            <strong>{m.role === "user" ? "Vous" : "Agent"}:</strong>{" "}
            {m.content}
            {streaming && i === messages.length - 1 && m.role === "assistant" && (
              <span>▌</span>
            )}
          </p>
        ))}
      </div>
      <form onSubmit={handleSubmit} style={{display: "flex", gap: 8}}>
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          disabled={streaming}
          placeholder="Ex: How many people in the database ?"
          style={{flex: 1, padding: "0.5rem"}}
        />
        <button type="submit" disabled={streaming || !input.trim()}>
          {streaming ? "…" : "Send"}
        </button>
      </form>
    </div>
  );
}
