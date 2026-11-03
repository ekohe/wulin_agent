/**
 * Pick up the host page's font and nav height at runtime, onto the panel root
 * or the toolbar toggle's slot. Colors are compiled in from wulin_master's theme.
 */
export function syncWulinTheme(target) {
  if (!target) return;

  const bodyStyle = getComputedStyle(document.body);
  target.style.setProperty("--wulin-agent-font", bodyStyle.fontFamily);

  const nav = document.querySelector("nav");
  if (nav) {
    const height = getComputedStyle(nav).height;
    if (height && height !== "0px") {
      target.style.setProperty("--wulin-agent-nav-height", height);
    }
  }
}
