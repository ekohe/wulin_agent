import {useEffect, useState} from "react";
import {attachmentIcon} from "../attachmentTypes";
import {
  clearPendingArchive,
  getPendingArchive,
  subscribePendingArchive,
} from "../pendingArchive";

export function PendingArchiveChip() {
  const [archive, setArchive] = useState(getPendingArchive);

  useEffect(() => subscribePendingArchive(setArchive), []);

  if (!archive) return null;

  const modeClass = archive.inject_mode
    ? ` wulin-agent-composer__attachment--${archive.inject_mode}`
    : "";

  return (
    <div className={`wulin-agent-composer__attachment${modeClass}`}>
      <span className="material-icons" aria-hidden="true">
        {attachmentIcon(archive.filename)}
      </span>
      <div className="wulin-agent-composer__attachment-body">
        <span className="wulin-agent-composer__attachment-label">
          {archive.filename} · {archive.file_count} file
          {archive.file_count === 1 ? "" : "s"}
        </span>
        {archive.inject_message && (
          <span className="wulin-agent-composer__attachment-hint">
            {archive.inject_message}
          </span>
        )}
      </div>
      <button
        type="button"
        className="wulin-agent-composer__attachment-remove"
        aria-label="Remove attachment"
        onClick={clearPendingArchive}
      >
        <span className="material-icons" aria-hidden="true">
          close
        </span>
      </button>
    </div>
  );
}
