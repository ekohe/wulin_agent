export function isLastAssistantInTurn(messages, messageIndex) {
  if (messages[messageIndex]?.role !== "assistant") return false;

  for (let i = messageIndex + 1; i < messages.length; i++) {
    if (messages[i].role === "user") return true;
    if (messages[i].role === "assistant") return false;
  }

  return true;
}

export function isInLatestTurn(messages, messageIndex) {
  const lastUserIndex = messages.findLastIndex((message) => message.role === "user");
  return messageIndex > lastUserIndex;
}

export function isLatestTurnComplete(messages, thread) {
  if (thread.isRunning && !thread.capabilities?.queue) return false;

  const last = messages.at(-1);
  return last?.status?.type !== "requires-action";
}

export function shouldShowTurnFeedback(messages, message, thread) {
  const messageIndex = messages.indexOf(message);
  if (messageIndex < 0 || message.role !== "assistant") return false;
  if (!isLastAssistantInTurn(messages, messageIndex)) return false;
  if (!message.metadata?.custom?.messageId) return false;

  if (isInLatestTurn(messages, messageIndex) && !isLatestTurnComplete(messages, thread)) {
    return false;
  }

  return true;
}
