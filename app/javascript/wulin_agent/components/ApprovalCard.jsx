import {useEffect, useState} from "react";
import {
  isDestructiveToolName,
  isFlatApprovalArgs,
  parseApprovalDraft,
  setApprovalDraft,
} from "../approvalDrafts";
import {strings} from "../strings";

export function ApprovalCard({toolName, args, approval, respondToApproval}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(args);
  const [draftText, setDraftText] = useState(() => JSON.stringify(args ?? {}, null, 2));
  const [parseError, setParseError] = useState("");
  const destructive = isDestructiveToolName(toolName);
  const hasArgs = args && Object.keys(args).length > 0;
  const flat = hasArgs && isFlatApprovalArgs(args);

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
        {" "}requires your approval
      </p>
      {hasArgs && (
        editing ? (
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
        {!editing ? (
          <>
            <button type="button" className="wulin-agent-approval__edit" onClick={() => setEditing(true)}>
              Edit
            </button>
            <button
              type="button"
              className={`wulin-agent-approval__approve${destructive ? " wulin-agent-approval__approve--danger" : ""}`}
              onClick={handleApprove}
            >
              Approve
            </button>
            <button type="button" className="wulin-agent-approval__reject" onClick={handleReject}>
              Reject
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
              Save & Approve
            </button>
            <button type="button" className="wulin-agent-approval__reject" onClick={handleCancel}>
              Cancel
            </button>
          </>
        )}
      </div>
    </div>
  );
}
