import {useAuiState} from "@assistant-ui/react";
import {isFirstAssistantInTurn, isLastAssistantInTurn, shouldShowTurnFeedback} from "./turnFeedback";

export function useShowTurnFeedback() {
  return useAuiState((state) =>
    shouldShowTurnFeedback(state.thread.messages, state.message, state.thread)
  );
}

export function useShowTurnCopy() {
  return useAuiState((state) => {
    const messages = state.thread.messages;
    const index = messages.indexOf(state.message);
    if (!isLastAssistantInTurn(messages, index)) return false;
    return !state.thread.isRunning;
  });
}

export function useShowTurnRole() {
  return useAuiState((state) =>
    isFirstAssistantInTurn(state.thread.messages, state.thread.messages.indexOf(state.message))
  );
}
