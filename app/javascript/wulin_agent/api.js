const BASE = "/wulin_agent/conversations";
const STORAGE_CONVERSATION_KEY = "wulin_agent_conversation_id";
const STORAGE_APPROVAL_MODE_KEY = "wulin_agent_approval_mode";

let conversationId = sessionStorage.getItem(STORAGE_CONVERSATION_KEY);
let pendingApprovalMode =
  sessionStorage.getItem(STORAGE_APPROVAL_MODE_KEY) ?? "confirm_writes";

let onConversationCreated = null;

export function setOnConversationCreated(cb) {
  onConversationCreated = cb;
}

export function getConversationId() {
  return conversationId;
}

export function resetConversationId() {
  conversationId = null;
  sessionStorage.removeItem(STORAGE_CONVERSATION_KEY);
}

export function setConversationId(id) {
  conversationId = id != null ? String(id) : null;
  if (conversationId) {
    sessionStorage.setItem(STORAGE_CONVERSATION_KEY, conversationId);
  } else {
    sessionStorage.removeItem(STORAGE_CONVERSATION_KEY);
  }
}

export function getStoredConversationId() {
  return sessionStorage.getItem(STORAGE_CONVERSATION_KEY);
}

export function setPendingApprovalMode(mode) {
  pendingApprovalMode = mode;
  sessionStorage.setItem(STORAGE_APPROVAL_MODE_KEY, mode);
}

export function getStoredApprovalMode() {
  return sessionStorage.getItem(STORAGE_APPROVAL_MODE_KEY);
}

export function getPendingApprovalMode() {
  return pendingApprovalMode;
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

export async function sendMessage(message, explicitConversationId, {archiveId, signal} = {}) {
  const id = explicitConversationId ?? conversationId;
  const body = {message};
  if (archiveId) {
    body.archive_id = archiveId;
  }
  if (id != null) {
    body.conversation_id = id;
  } else {
    body.approval_mode = pendingApprovalMode;
  }

  const response = await fetch(BASE, {
    method: "POST",
    credentials: "include",
    headers: jsonHeaders(),
    body: JSON.stringify(body),
    signal,
  });

  if (response.status === 401) {
    throw new Error("Unauthorized (401)");
  }
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  const newConversationId =
    response.headers.get("X-Conversation-Id") ?? id;

  if (newConversationId != null) {
    setConversationId(newConversationId);
  }

  if (id == null && newConversationId != null) {
    onConversationCreated?.(newConversationId);
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

export async function sendFeedback(rating, messageId, { signal } = {}) {
  const id = conversationId;
  if (id == null) throw new Error("No conversation");

  const response = await fetch(`${BASE}/${id}/feedback`, {
    method: "POST",
    credentials: "include",
    headers: jsonHeaders(),
    body: JSON.stringify({ rating, message_id: messageId }),
    signal,
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  return response.json(); // { message_id, rating }
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

export async function fetchAgentConfig({ signal } = {}) {
  const response = await fetch(`${BASE}/agent_config`, {
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

  return response.json(); // { model: "gpt-4o-mini" }
}



export async function uploadArchive(file, { signal } = {}) {
  const formData = new FormData();
  formData.append("file", file);

  const response = await fetch(`${BASE}/upload_archive`, {
    method: "POST",
    credentials: "include",
    headers: {
      Accept: "application/json",
      "X-CSRF-Token": csrfToken(),
    },
    body: formData,
    signal,
  });

  if (response.status === 401) {
    throw new Error("Unauthorized (401)");
  }

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error || `HTTP ${response.status}`);
  }

  return data;
}

export async function deleteConversation(id, { signal } = {}) {
  const response = await fetch(`${BASE}/${id}`, {
    method: "DELETE",
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
}

export async function updateApprovalMode(id, approvalMode, { signal } = {}) {
  const response = await fetch(`${BASE}/${id}`, {
    method: "PATCH",
    credentials: "include",
    headers: {
      ...jsonHeaders(),
      Accept: "application/json",
    },
    body: JSON.stringify({ approval_mode: approvalMode }),
    signal,
  });

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }

  return response.json(); // { id, approval_mode }
}