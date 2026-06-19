/** Pick up Wulin Master theme colors from the host page at runtime. */
export function syncWulinTheme(root) {
  if (!root) return;

  const bodyStyle = getComputedStyle(document.body);
  root.style.setProperty("--wulin-agent-font", bodyStyle.fontFamily);

  const nav = document.querySelector("nav");
  if (nav) {
    const navStyle = getComputedStyle(nav);
    const main = navStyle.backgroundColor;
    if (main && main !== "rgba(0, 0, 0, 0)") {
      root.style.setProperty("--wulin-agent-main", main);
    }
    const height = navStyle.height;
    if (height && height !== "0px") {
      root.style.setProperty("--wulin-agent-nav-height", height);
    }
  }

  const accent =
    document.querySelector(".toolbar-global .toolbar_item a") ||
    document.querySelector("#navigation #menu ul li.item.active a");
  if (accent) {
    const color = getComputedStyle(accent).color;
    if (color) root.style.setProperty("--wulin-agent-main", color);
  }

  const menu = document.querySelector("#navigation");
  if (menu) {
    const bg = getComputedStyle(menu).backgroundColor;
    if (bg && bg !== "rgba(0, 0, 0, 0)") {
      root.style.setProperty("--wulin-agent-bg-subtle", bg);
    }
  }
}
