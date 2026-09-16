import {attachmentIcon} from "../attachmentTypes";

export function MessageArchiveAttachment({archive}) {
  if (!archive?.archive_id) return null;

  const modeClass = archive.inject_mode
    ? ` wulin-agent-message__attachment--${archive.inject_mode}`
    : "";

  return (
    <div className={`wulin-agent-message__attachment${modeClass}`}>
      <i className="material-icons" aria-hidden="true">
        {attachmentIcon(archive.filename)}
      </i>
      <div className="wulin-agent-message__attachment-body">
        <span className="wulin-agent-message__attachment-label">
          {archive.filename || "attachment"} · {archive.file_count ?? "?"} file
          {archive.file_count === 1 ? "" : "s"}
        </span>
        {archive.inject_message && (
          <span className="wulin-agent-message__attachment-hint">
            {archive.inject_message}
          </span>
        )}
      </div>
    </div>
  );
}
