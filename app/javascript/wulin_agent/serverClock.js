// Approval deadlines are the server's clock; a browser whose clock is off by
// minutes would count down to the wrong moment. Every conversation response
// carries X-Server-Time, and deadlines are compared against serverNow().
let offset = 0;

export function noteServerTime(response) {
  const stamp = Date.parse(response.headers.get("X-Server-Time") ?? "");
  if (!Number.isNaN(stamp)) offset = stamp - Date.now();
}

export function serverNow() {
  return Date.now() + offset;
}
