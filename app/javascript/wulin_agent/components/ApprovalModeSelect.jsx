const MODES = [
  {value: "confirm_writes", label: "Confirm writes"},
  {value: "auto", label: "Auto"},
  {value: "confirm_all", label: "Confirm all"},
];

export function ApprovalModeSelect({value, onChange, disabled = false}) {
  return (
    <select
      className="wulin-agent-approval-mode"
      value={value}
      disabled={disabled}
      onChange={(e) => onChange(e.target.value)}
      aria-label="Approval mode"
    >
      {MODES.map((mode) => (
        <option key={mode.value} value={mode.value}>
          {mode.label}
        </option>
      ))}
    </select>
  );
}
