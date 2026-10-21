const MARKS = {
  running: {icon: "sync", label: "Running"},
  complete: {icon: "check", label: "Complete"},
  rejected: {icon: "block", label: "Rejected"},
  failed: {icon: "error", label: "Failed"},
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
