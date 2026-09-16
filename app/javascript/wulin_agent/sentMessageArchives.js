import {archiveDisplayMeta} from "./pendingArchive";

const byKey = new Map();

function storageKey(text, archiveId) {
  const trimmed = text.trim();
  if (trimmed) return trimmed;
  return `archive:${archiveId}`;
}

export function registerSentArchive(text, archive) {
  if (!archive?.archive_id) return;

  byKey.set(storageKey(text, archive.archive_id), archiveDisplayMeta(archive));
}

export function lookupSentArchive(text, archiveId) {
  if (archiveId) {
    const byArchive = byKey.get(`archive:${archiveId}`);
    if (byArchive) return byArchive;
  }

  const trimmed = text.trim();
  if (!trimmed) return null;

  return byKey.get(trimmed) ?? null;
}
