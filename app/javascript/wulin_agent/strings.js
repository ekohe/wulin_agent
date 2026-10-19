export const strings = {
  composerPlaceholder: "Ask about this data",
  deleteConversation: "Delete this conversation?",
  gridSummary(total) {
    return `${total} ${total === 1 ? "result" : "results"}`;
  },
  gridWindow(from, to) {
    return `showing ${from}–${to}`;
  },
  gridEmpty: "No rows.",
};
