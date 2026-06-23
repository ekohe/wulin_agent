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