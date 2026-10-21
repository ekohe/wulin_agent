import {strings} from "../strings";

const MARKS = {
  running: {icon: "sync", label: strings.status.running},
  complete: {icon: "check", label: strings.status.complete},
  rejected: {icon: "block", label: strings.status.rejected},
  failed: {icon: "error", label: strings.status.failed},
};

export function StatusMark({status}) {
  const mark = MARKS[status];
  if (!mark) return null;

  return (
    <span className={`wulin-agent-status wulin-agent-status--${status}`}>
      <span className="material-icons" aria-hidden="true">{mark.icon}</span>
      {mark.label}
    </span>
  );
}
