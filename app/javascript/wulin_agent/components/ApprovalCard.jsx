import { useState } from "react";
import { useEffect } from "react";
import { setApprovalDraft } from "../approvalDrafts";



export function ApprovalCard({toolName, args, approval, respondToApproval}) {

const [editing, setEditing] = useState(false);
const [draft, setDraft] = useState(args);


useEffect(() => {
  setDraft(args);
}, [args]);

const handleApprove = () => {
  if (approval?.id) {
    setApprovalDraft(approval.id, draft);
  }
  respondToApproval({ approved: true }); 
  setEditing(false);
};

const handleCancel = () => {
  setDraft(args);
  setEditing(false);
};

const handleReject = () => {
  respondToApproval({ approved: false, reason: "User declined" });
};

  return (
    <div className="wulin-agent-approval wulin-agent-approval--pending">
      <p className="wulin-agent-approval__title">
        <span className="wulin-agent-approval__tool">{toolName}</span>
        {" "}requires your approval
      </p>
      {args && Object.keys(args).length > 0 && (
        editing ? (
          <textarea
            className="wulin-agent-approval__args wulin-agent-approval__textarea"
            value={JSON.stringify(draft, null, 2)}
            onChange={(e) => {
              try {
                setDraft(JSON.parse(e.target.value));
              } catch {
                // JSON error, ignore for now
              }
            }}
          />
        ) : (
          <pre className="wulin-agent-approval__args">
            {JSON.stringify(args, null, 2)}
          </pre>
        )
      )}
      <div className="wulin-agent-approval__actions">
        {!editing ? (
          <>
            <button
              type="button"
              className="wulin-agent-approval__edit"
              onClick={() => setEditing(true)}
            >
              Edit
            </button>

            <button
              type="button"
              className="wulin-agent-approval__approve"
              onClick={handleApprove}
            >
              Approve
            </button>

            <button
              type="button"
              className="wulin-agent-approval__reject"
              onClick={handleReject}
            >
              Reject
            </button>
          </>
        ) : (
          <>
            <button
              type="button"
              className="wulin-agent-approval__approve"
              onClick={handleApprove}
            >
              Save & Approve
            </button>

            <button
              type="button"
              className="wulin-agent-approval__reject"
              onClick={handleCancel}
            >
              Cancel
            </button>
          </>
        )}
      </div>
    </div>
  );
}
