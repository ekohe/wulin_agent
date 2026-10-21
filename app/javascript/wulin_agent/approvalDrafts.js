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

export function parseApprovalDraft(text) {
  try {
    return {ok: true, value: JSON.parse(text)};
  } catch {
    return {ok: false, value: null};
  }
}