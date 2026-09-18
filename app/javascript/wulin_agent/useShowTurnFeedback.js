import {useAuiState} from "@assistant-ui/react";
import {shouldShowTurnFeedback} from "./turnFeedback";

export function useShowTurnFeedback() {
  return useAuiState((state) =>
    shouldShowTurnFeedback(state.thread.messages, state.message, state.thread)
  );
}
