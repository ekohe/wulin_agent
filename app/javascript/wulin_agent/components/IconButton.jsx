export function IconButton({icon, label, className, type = "button", ...rest}) {
  const classes = ["wulin-agent-icon-button", className].filter(Boolean).join(" ");

  return (
    <button type={type} className={classes} aria-label={label} {...rest}>
      <i className="material-icons" aria-hidden="true">{icon}</i>
    </button>
  );
}
