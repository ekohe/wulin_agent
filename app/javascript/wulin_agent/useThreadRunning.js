import {useAuiState} from "@assistant-ui/react";

export function useThreadRunning() {
  return useAuiState(
    (state) => state.thread.isRunning && !state.thread.capabilities.queue
  );
}
