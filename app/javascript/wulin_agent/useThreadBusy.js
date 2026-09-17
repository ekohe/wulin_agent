import {useAuiState} from "@assistant-ui/react";

export function useThreadBusy() {
  return useAuiState((state) => {
    if (state.thread.isRunning && !state.thread.capabilities.queue) return true;

    const last = state.thread.messages.at(-1);
    return last?.role === "assistant" && last.status?.type === "requires-action";
  });
}
