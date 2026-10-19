import {useAuiState} from "@assistant-ui/react";
import {isFirstAssistantInTurn, shouldShowTurnFeedback} from "./turnFeedback";

export function useShowTurnFeedback() {
  return useAuiState((state) =>
    shouldShowTurnFeedback(state.thread.messages, state.message, state.thread)
  );
}

export function useShowTurnRole() {
  return useAuiState((state) =>
    isFirstAssistantInTurn(state.thread.messages, state.thread.messages.indexOf(state.message))
  );
}
