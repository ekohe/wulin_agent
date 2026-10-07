import {useCallback, useEffect, useRef, useState} from "react";
import {createToken, listTokens, revokeToken} from "../tokenApi";

function dateLabel(value) {
  return new Date(value).toLocaleString(undefined, {dateStyle: "medium", timeStyle: "short"});
}

function TokenDialog({onClose}) {
  const dialog = useRef(null);
  const [tokens, setTokens] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [name, setName] = useState("");
  const [expiry, setExpiry] = useState("30");
  const [newToken, setNewToken] = useState(null);
  const [copied, setCopied] = useState(false);
  const [revoking, setRevoking] = useState(null);

  useEffect(() => {
    const controller = new AbortController();
    dialog.current.showModal();
    listTokens(controller.signal)
      .then(setTokens)
      .catch((failure) => {
        if (!controller.signal.aborted) setError(failure.message);
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    return () => controller.abort();
  }, []);

  async function handleCreate(event) {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      const {token, ...metadata} = await createToken(name.trim(), expiry);
      setTokens((current) => [metadata, ...current]);
      setNewToken({token, name: metadata.name, id: metadata.id});
      setCopied(false);
      setName("");
    } catch (failure) {
      setError(failure.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleRevoke(id) {
    setBusy(true);
    setError("");
    try {
      await revokeToken(id);
      setTokens((current) => current.filter((token) => token.id !== id));
      if (newToken?.id === id) setNewToken(null);
      setRevoking(null);
    } catch (failure) {
      setError(failure.message);
    } finally {
      setBusy(false);
    }
  }

  async function copyToken() {
    try {
      await navigator.clipboard.writeText(newToken.token);
      setCopied(true);
    } catch {
      setError("Clipboard unavailable. Select the token below and copy it manually.");
    }
  }

  return (
    <dialog
      ref={dialog}
      className="wulin-agent-tokens"
      aria-labelledby="wulin-agent-tokens-title"
      onCancel={(event) => { event.preventDefault(); if (!busy) onClose(); }}
      onClose={onClose}
    >
      <header className="wulin-agent-tokens__header">
        <div>
          <span className="wulin-agent-tokens__eyebrow">External connections</span>
          <h2 id="wulin-agent-tokens-title">MCP tokens</h2>
        </div>
        <button type="button" className="wulin-agent-panel__close" aria-label="Close token manager" disabled={busy} onClick={onClose}>×</button>
      </header>
      <p className="wulin-agent-tokens__intro">Connect your MCP client to Wulin Agent using your account permissions.</p>
      <div className="wulin-agent-tokens__endpoint">
        <span>Server URL</span>
        <code>{window.location.origin}/wulin_agent/mcp</code>
      </div>
      <p className="wulin-agent-tokens__notice">Token holders can use Wulin Agent’s tools with your permissions. MCP actions run without the chat approval prompt.</p>
      {error && <p className="wulin-agent-tokens__error" role="alert">{error}</p>}
      {newToken && (
        <section className="wulin-agent-tokens__reveal" aria-label="New token" aria-live="polite">
          <h3>Copy your token now</h3>
          <p>“{newToken.name}” is ready. This token will not be shown again after you close this popup.</p>
          <label htmlFor="wulin-agent-new-token">New token</label>
          <div className="wulin-agent-tokens__copy-row">
            <input id="wulin-agent-new-token" value={newToken.token} readOnly autoComplete="off" spellCheck={false} onFocus={(event) => event.target.select()} />
            <button type="button" className="wulin-agent-tokens__button" onClick={copyToken}>{copied ? "Copied" : "Copy token"}</button>
          </div>
          <p>Use it in your client’s <code>Authorization: Bearer &lt;token&gt;</code> header.</p>
          <button type="button" className="wulin-agent-tokens__text-button" onClick={() => setNewToken(null)}>I’ve saved my token</button>
        </section>
      )}
      <section className="wulin-agent-tokens__list" aria-labelledby="wulin-agent-active-tokens">
        <h3 id="wulin-agent-active-tokens">Active tokens <span>{tokens.length}</span></h3>
        {loading ? <p role="status">Loading tokens…</p> : tokens.length === 0 ? <p>No active tokens. Create one for each client you want to connect.</p> : (
          <ul>
            {tokens.map((token) => (
              <li key={token.id}>
                <div className="wulin-agent-tokens__token-info">
                  <strong>{token.name || "Unnamed token"}</strong>
                  <span>Created {dateLabel(token.created_at)}</span>
                  <span>Last used: {token.last_used_at ? dateLabel(token.last_used_at) : "Never"}</span>
                  <span>{token.expires_at ? `Expires ${dateLabel(token.expires_at)}` : "No expiration"}</span>
                </div>
                {revoking === token.id ? (
                  <div className="wulin-agent-tokens__revoke">
                    <span>Disconnect this client?</span>
                    <button type="button" className="wulin-agent-tokens__text-button wulin-agent-tokens__danger" disabled={busy} onClick={() => handleRevoke(token.id)}>Confirm revocation</button>
                    <button type="button" className="wulin-agent-tokens__text-button" disabled={busy} onClick={() => setRevoking(null)}>Cancel</button>
                  </div>
                ) : <button type="button" className="wulin-agent-tokens__text-button wulin-agent-tokens__danger" disabled={busy} aria-label={`Revoke ${token.name || "unnamed token"}`} onClick={() => setRevoking(token.id)}>Revoke</button>}
              </li>
            ))}
          </ul>
        )}
      </section>
      <form className="wulin-agent-tokens__form" onSubmit={handleCreate}>
        <h3>Create a token</h3>
        <div className="wulin-agent-tokens__fields">
          <div>
            <label htmlFor="wulin-agent-token-name">Token name</label>
            <input id="wulin-agent-token-name" placeholder="e.g. Codex on my laptop" value={name} onChange={(event) => setName(event.target.value)} maxLength={100} required disabled={busy || !!newToken} autoComplete="off" />
          </div>
          <div>
            <label htmlFor="wulin-agent-token-expiry">Expires after</label>
            <div className="wulin-agent-tokens__select">
              <select id="wulin-agent-token-expiry" value={expiry} onChange={(event) => setExpiry(event.target.value)} disabled={busy || !!newToken}>
                <option value="7">7 days</option>
                <option value="30">30 days</option>
                <option value="90">90 days</option>
                <option value="365">1 year</option>
                <option value="never">Never</option>
              </select>
              <span className="wulin-agent-tokens__select-chevron" aria-hidden="true" />
            </div>
          </div>
        </div>
        <button type="submit" className="wulin-agent-tokens__button wulin-agent-tokens__button--primary" disabled={loading || busy || !name.trim() || !!newToken}>{busy ? "Saving…" : "Create token"}</button>
      </form>
    </dialog>
  );
}

export function McpTokenManager() {
  const [open, setOpen] = useState(false);
  const trigger = useRef(null);
  const opened = useRef(false);
  const close = useCallback(() => {
    setOpen(false);
  }, []);

  useEffect(() => {
    if (open) opened.current = true;
    else if (opened.current) trigger.current?.focus();
  }, [open]);

  return (
    <>
      <button ref={trigger} type="button" className="wulin-agent-tokens__trigger" aria-haspopup="dialog" onClick={() => setOpen(true)}>
        <i className="material-icons" aria-hidden="true">vpn_key</i>
        MCP tokens
      </button>
      {open && <TokenDialog onClose={close} />}
    </>
  );
}
