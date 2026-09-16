import {useEffect, useState} from "react";
import {useAui, useAuiState, useThreadRuntime} from "@assistant-ui/react";
import {
  archiveDisplayMeta,
  getPendingArchive,
  subscribePendingArchive,
  takePendingArchive,
} from "../pendingArchive";

export function ComposerSendButton() {
  const aui = useAui();
  const text = useAuiState((state) => state.composer.text);
  const canSend = useAuiState((state) => state.composer.canSend);
  const isRunning = useAuiState(
    (state) => state.thread.isRunning && !state.thread.capabilities.queue
  );
  const thread = useThreadRuntime();
  const [pendingArchive, setPendingArchive] = useState(getPendingArchive);

  useEffect(() => subscribePendingArchive(setPendingArchive), []);

  const hasText = text.trim().length > 0;
  const hasArchive = Boolean(pendingArchive);
  const canSubmit = !isRunning && ((hasText && canSend) || (hasArchive && !hasText));

  const sendWithArchive = () => {
    const archive = takePendingArchive();
    const content = hasText ? [{type: "text", text: text.trim()}] : [];

    thread.append({
      role: "user",
      content,
      metadata: {custom: {archive: archiveDisplayMeta(archive)}},
      startRun: true,
    });

    if (hasText) {
      aui.composer().reset();
    }
  };

  const handleClick = () => {
    if (!canSubmit) return;

    if (hasArchive) {
      sendWithArchive();
      return;
    }

    if (hasText && canSend) {
      aui.composer().send();
    }
  };

  return (
    <button
      type="button"
      className="wulin-agent-composer__send"
      disabled={!canSubmit}
      onClick={handleClick}
    >
      Send
    </button>
  );
}
