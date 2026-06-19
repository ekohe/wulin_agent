const BASE = "/agent/conversations";

let conversationId = null;

export function getConversationId() {
  return conversationId;
}

export function resetConversationId() {
  conversationId = null;
}

export function setConversationId(id) {
  conversationId = id != null ? String(id) : null;
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

function getHeaders() {
  return {
    Accept: "application/json",
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

export async function runApproved({ token, params, signal } = {}) {
  const id = conversationId;
  if (id == null) throw new Error("No conversation");

  const response = await fetch(`${BASE}/${id}/approve`, {
    method: "POST",
    credentials: "include",
    headers: jsonHeaders(),
    body: JSON.stringify({ token, params }),
    signal,
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  return { body: response.body };
}

export async function runRejected({ token, reason, signal } = {}) {
  const id = conversationId;
  if (id == null) throw new Error("No conversation");

  const response = await fetch(`${BASE}/${id}/reject`, {
    method: "POST",
    credentials: "include",
    headers: jsonHeaders(),
    body: JSON.stringify({ token, reason }),
    signal,
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  return { body: response.body };
}

export async function listConversations({ signal } = {}) {
  const response = await fetch(BASE,{
    method: "GET",
    credentials: "include",
    headers: getHeaders(),
    signal,
  });
  if (response.status === 401) {
    throw new Error("Not authenticated (401)");
  }
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return response.json();
}

export async function fetchConversation(id, { signal } = {}) {
  const response = await fetch(`${BASE}/${id}`, {
    method: "GET",
    credentials: "include",
    headers: getHeaders(),
    signal,
  });

  if (response.status === 401) {
    throw new Error("Not authenticated (401)");
  }
  if (response.status === 404) {
    throw new Error("Conversation not found (404)");
  }
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  return response.json();
}

