import {strings} from "../strings";

const MODES = [
  {value: "confirm_writes", label: strings.approvalModes.confirm_writes},
  {value: "auto", label: strings.approvalModes.auto},
  {value: "confirm_all", label: strings.approvalModes.confirm_all},
];

export function ApprovalModeSelect({value, onChange, disabled = false}) {
  return (
    <select
      className="wulin-agent-approval-mode"
      value={value}
      disabled={disabled}
      onChange={(e) => onChange(e.target.value)}
      aria-label={strings.approvalModeLabel}
    >
      {MODES.map((mode) => (
        <option key={mode.value} value={mode.value}>
          {mode.label}
        </option>
      ))}
    </select>
  );
}
