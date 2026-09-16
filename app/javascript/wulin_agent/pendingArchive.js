let pending = null;
const listeners = new Set();

export function getPendingArchive() {
  return pending;
}

export function setPendingArchive(archive) {
  pending = archive;
  listeners.forEach((listener) => listener(pending));
}

export function takePendingArchive() {
  const value = pending;
  pending = null;
  listeners.forEach((listener) => listener(null));
  return value;
}

export function archiveDisplayMeta(archive) {
  if (!archive) return null;

  return {
    archive_id: archive.archive_id,
    filename: archive.filename,
    file_count: archive.file_count,
    inject_mode: archive.inject_mode,
    inject_message: archive.inject_message,
  };
}

export function clearPendingArchive() {
  setPendingArchive(null);
}

export function subscribePendingArchive(listener) {
  listener(pending);
  listeners.add(listener);
  return () => listeners.delete(listener);
}
