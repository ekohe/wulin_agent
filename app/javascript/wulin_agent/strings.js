export const strings = {
  composerPlaceholder: "Ask about this data",
  deleteConversation: "Delete this conversation?",
  approvalJsonInvalid: "That is not valid JSON. Fix it before approving.",
  awaitingApproval: "Awaiting approval",
  historyLoadFailed: "Could not load conversations.",
  historyDeleteFailed: "Could not delete that conversation.",
  historyOpenFailed: "Could not open that conversation.",
  feedbackFailed: "Could not save that rating.",
  configFailed: "Could not load the agent settings.",
  approvalModeFailed: "Could not save the approval mode.",
  gridSummary(total) {
    return `${total} ${total === 1 ? "result" : "results"}`;
  },
  gridWindow(from, to) {
    return `showing ${from}–${to}`;
  },
  gridEmpty: "No rows.",
};
