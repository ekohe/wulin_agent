import {useAuiState} from "@assistant-ui/react";

export function useThreadRunning() {
  return useAuiState(
    (state) => state.thread.isRunning && !state.thread.capabilities.queue
  );
}

export function useThreadThinking() {
  return useAuiState((state) => {
    if (!state.thread.isRunning || state.thread.capabilities.queue) return false;

    const last = state.thread.messages.at(-1);
    if (!last || last.role === "user") return true;
    if (last.status?.type === "requires-action") return false;

    const hasVisibleText = last.content.some(
      (part) => part.type === "text" && part.text?.trim()
    );
    if (hasVisibleText) return false;

    const hasToolCalls = last.content.some((part) => part.type === "tool-call");
    return !hasToolCalls;
  });
}
