export const strings = {
  composerPlaceholder: "Ask about this data",
  deleteConversation: "Delete this conversation?",
  approvalJsonInvalid: "That is not valid JSON. Fix it before approving.",
  gridSummary(total) {
    return `${total} ${total === 1 ? "result" : "results"}`;
  },
  gridWindow(from, to) {
    return `showing ${from}–${to}`;
  },
  gridEmpty: "No rows.",
};
