/**
 * Pick up the host page's font and nav height at runtime. Colors come from
 * wulin_master's theme when dart-sass builds wulin_agent.scss.
 */
export function syncWulinTheme(root) {
  if (!root) return;

  const bodyStyle = getComputedStyle(document.body);
  root.style.setProperty("--wulin-agent-font", bodyStyle.fontFamily);

  const nav = document.querySelector("nav");
  if (nav) {
    const height = getComputedStyle(nav).height;
    if (height && height !== "0px") {
      root.style.setProperty("--wulin-agent-nav-height", height);
    }
  }
}
