import {useAuiState} from "@assistant-ui/react";
import {isFirstAssistantInTurn, isLastAssistantInTurn, shouldShowTurnFeedback, turnText} from "./turnFeedback";

export function useShowTurnFeedback() {
  return useAuiState((state) =>
    shouldShowTurnFeedback(state.thread.messages, state.message, state.thread)
  );
}

// What the turn's Copy button copies, on the turn's last assistant message once
// the run has finished; "" when there is no button: elsewhere, while running,
// or when the turn has no text (only tool calls, or a pending approval).
export function useTurnCopyText() {
  return useAuiState((state) => {
    const messages = state.thread.messages;
    const index = messages.indexOf(state.message);
    if (state.thread.isRunning || !isLastAssistantInTurn(messages, index)) return "";
    return turnText(messages, index);
  });
}

export function useShowTurnRole() {
  return useAuiState((state) =>
    isFirstAssistantInTurn(state.thread.messages, state.thread.messages.indexOf(state.message))
  );
}
