const BASE = "/agent/conversations";

let conversationId = null;

export function getConversationId() {
  return conversationId;
}

export function resetConversationId() {
  conversationId = null;
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content;
}

function jsonHeaders() {
  return {
    "Content-Type": "application/json",
    Accept: "text/plain",
    "X-CSRF-Token": csrfToken(),
  };
}

export async function sendMessage(message, explicitConversationId, {signal} = {}) {
  const id = explicitConversationId ?? conversationId;
  const body = {message};
  if (id != null) body.conversation_id = id;

  const response = await fetch(BASE, {
    method: "POST",
    credentials: "include",
    headers: jsonHeaders(),
    body: JSON.stringify(body),
    signal,
  });

  if (response.status === 401) {
    throw new Error("Non authentifié (401)");
  }
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  const newConversationId =
    response.headers.get("X-Conversation-Id") ?? id;

  if (newConversationId != null) {
    conversationId = String(newConversationId);
  }

  return {body: response.body, conversationId: newConversationId};
}
