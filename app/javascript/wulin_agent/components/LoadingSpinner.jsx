export function LoadingSpinner({className = "", label}) {
  return (
    <span
      className={`wulin-agent-spinner${className ? ` ${className}` : ""}`}
      role="status"
      aria-label={label}
      aria-hidden={label ? undefined : true}
    />
  );
}
