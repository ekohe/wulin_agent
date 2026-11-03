const drafts = new Map();

export function setApprovalDraft(token, params) {
  drafts.set(token, params);
}

export function getApprovalDraft(token) {
  return drafts.get(token);
}

export function clearApprovalDraft(token) {
  drafts.delete(token);
}

export function isFlatApprovalArgs(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  return Object.values(value).every((item) => (
    item == null || ["string", "number", "boolean"].includes(typeof item)
  ));
}

export function isDestructiveToolName(name) {
  return /destroy|delete/i.test(name || "");
}

export function parseApprovalDraft(text) {
  try {
    return {ok: true, value: JSON.parse(text)};
  } catch {
    return {ok: false, value: null};
  }
}