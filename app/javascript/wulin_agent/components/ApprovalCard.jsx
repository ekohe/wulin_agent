import {useEffect, useState} from "react";
import {
  isDestructiveToolName,
  isFlatApprovalArgs,
  parseApprovalDraft,
  setApprovalDraft,
} from "../approvalDrafts";
import {serverNow} from "../serverClock";
import {strings} from "../strings";

const SOON_SECONDS = 60;

// Seconds left before the server stops accepting an answer, ticking once a
// second; null when the request carries no expiry (older stored messages).
function useSecondsLeft(expiresAt) {
  const deadline = expiresAt ? Date.parse(expiresAt) : NaN;
  const left = () => Math.max(0, Math.ceil((deadline - serverNow()) / 1000));
  const [seconds, setSeconds] = useState(() => (Number.isNaN(deadline) ? null : left()));

  useEffect(() => {
    if (Number.isNaN(deadline)) return undefined;
    setSeconds(left());
    const timer = setInterval(() => {
      const next = left();
      setSeconds(next);
      if (next === 0) clearInterval(timer);
    }, 1000);
    return () => clearInterval(timer);
  }, [deadline]);

  return seconds;
}

export function ApprovalCard({toolName, args, approval, respondToApproval}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(args);
  const [draftText, setDraftText] = useState(() => JSON.stringify(args ?? {}, null, 2));
  const [parseError, setParseError] = useState("");
  const destructive = isDestructiveToolName(toolName);
  const hasArgs = args && Object.keys(args).length > 0;
  const flat = hasArgs && isFlatApprovalArgs(args);
  const secondsLeft = useSecondsLeft(approval?.expiresAt);
  const expired = secondsLeft === 0;

  useEffect(() => {
    setDraft(args);
    setDraftText(JSON.stringify(args ?? {}, null, 2));
    setParseError("");
  }, [args]);

  const handleApprove = () => {
    if (parseError) return;
    if (approval?.id) setApprovalDraft(approval.id, draft);
    respondToApproval({approved: true});
    setEditing(false);
  };

  const handleCancel = () => {
    setDraft(args);
    setDraftText(JSON.stringify(args ?? {}, null, 2));
    setParseError("");
    setEditing(false);
  };

  const handleReject = () => {
    respondToApproval({approved: false, reason: "User declined"});
  };

  // The server records an answer to an expired request as expired; this only
  // lets the turn move on.
  const handleDismiss = () => {
    respondToApproval({approved: false, reason: "Expired"});
  };

  const handleDraftChange = (event) => {
    const next = event.target.value;
    setDraftText(next);
    const parsed = parseApprovalDraft(next);
    if (parsed.ok) {
      setDraft(parsed.value);
      setParseError("");
    } else {
      setParseError(strings.approvalJsonInvalid);
    }
  };

  const cardClass = [
    "wulin-agent-approval",
    "wulin-agent-approval--pending",
    destructive ? "wulin-agent-approval--destructive" : "",
  ].filter(Boolean).join(" ");

  return (
    <div className={cardClass}>
      <p className="wulin-agent-approval__title">
        <span className="wulin-agent-approval__tool">{toolName}</span>
        {" "}{strings.requiresApproval}
      </p>
      {expired ? (
        <p className="wulin-agent-approval__expired" role="status">{strings.approvalExpired}</p>
      ) : secondsLeft != null && (
        <p className={`wulin-agent-approval__expiry${secondsLeft <= SOON_SECONDS ? " wulin-agent-approval__expiry--soon" : ""}`}>
          {strings.approvalExpiresIn(secondsLeft)}
        </p>
      )}
      {hasArgs && (
        editing && !expired ? (
          <>
            <textarea
              className="wulin-agent-approval__args wulin-agent-approval__textarea"
              value={draftText}
              aria-invalid={Boolean(parseError)}
              onChange={handleDraftChange}
            />
            {parseError && (
              <p className="wulin-agent-approval__error" role="alert">{parseError}</p>
            )}
          </>
        ) : flat ? (
          <dl className="wulin-agent-approval__fields">
            {Object.entries(args).map(([key, value]) => (
              <div key={key}>
                <dt>{key}</dt>
                <dd>{value == null || value === "" ? "—" : String(value)}</dd>
              </div>
            ))}
          </dl>
        ) : (
          <pre className="wulin-agent-approval__args">
            {JSON.stringify(args, null, 2)}
          </pre>
        )
      )}
      <div className="wulin-agent-approval__actions">
        {expired ? (
          <button type="button" className="wulin-agent-approval__reject" onClick={handleDismiss}>
            {strings.dismiss}
          </button>
        ) : !editing ? (
          <>
            <button type="button" className="wulin-agent-approval__edit" onClick={() => setEditing(true)}>
              {strings.edit}
            </button>
            <button
              type="button"
              className={`wulin-agent-approval__approve${destructive ? " wulin-agent-approval__approve--danger" : ""}`}
              onClick={handleApprove}
            >
              {strings.approve}
            </button>
            <button type="button" className="wulin-agent-approval__reject" onClick={handleReject}>
              {strings.reject}
            </button>
          </>
        ) : (
          <>
            <button
              type="button"
              className={`wulin-agent-approval__approve${destructive ? " wulin-agent-approval__approve--danger" : ""}`}
              onClick={handleApprove}
              disabled={Boolean(parseError)}
            >
              {strings.saveAndApprove}
            </button>
            <button type="button" className="wulin-agent-approval__reject" onClick={handleCancel}>
              {strings.cancel}
            </button>
          </>
        )}
      </div>
    </div>
  );
}
