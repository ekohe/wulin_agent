const BASE = "/wulin_agent/api_tokens";

async function request(path, {method = "GET", body, signal} = {}) {
  const response = await fetch(path, {
    method,
    credentials: "same-origin",
    cache: "no-store",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
    },
    body: body ? JSON.stringify(body) : undefined,
    signal,
  });
  if (response.status === 204) return;
  if (response.status === 401) throw new Error("Your session has expired. Sign in again to manage tokens.");
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    throw new Error(data.error || "Could not update your tokens. Please try again.");
  }
  return response.json();
}

export function listTokens(signal) {
  return request(BASE, {signal});
}

export function createToken(name, expiresInDays) {
  return request(BASE, {method: "POST", body: {name, expires_in_days: expiresInDays}});
}

export function revokeToken(id) {
  return request(`${BASE}/${encodeURIComponent(id)}`, {method: "DELETE"});
}
