// Every word the chat panel shows. The MCP token dialog keeps its own
// copy, which is formatted prose rather than labels.
export const strings = {
  panelTitle: "Wulin Agent",
  modelLabel: "Model",
  approvalModeLabel: "Approval mode",
  approvalModes: {
    confirm_writes: "Confirm writes",
    auto: "Auto",
    confirm_all: "Confirm all",
  },
  openAgent: "Open agent",
  closeAgent: "Close agent",
  focusAgent: "Focus agent",
  close: "Close",
  resizePanel: "Resize panel",
  awaitingApproval: "Awaiting approval",
  configFailed: "Could not load the agent settings.",
  approvalModeFailed: "Could not save the approval mode.",

  historyTitle(count) {
    return `History (${count})`;
  },
  newConversation: "+ New",
  showHistory: "Show history",
  hideHistory: "Hide history",
  resizeHistory: "Resize history",
  loading: "Loading…",
  deleteConversationLabel: "Delete conversation",
  deleteConversation: "Delete this conversation? This cannot be undone.",
  delete: "Delete",
  historyLoadFailed: "Could not load conversations.",
  historyDeleteFailed: "Could not delete that conversation.",
  historyOpenFailed: "Could not open that conversation.",

  emptyThread: "Ask anything",
  userRole: "User",
  agentRole: "Agent",
  working: "Working…",
  latest: "Latest",
  copy: "Copy",
  copied: "Copied",
  copyFailed: "Could not copy. Select the text and copy it yourself.",
  goodResponse: "Good response",
  badResponse: "Bad response",
  feedbackFailed: "Could not save that rating.",

  composerPlaceholder: "Ask about this data",
  send: "Send",
  attachFile: "Attach a file",
  attachHint: "Attach a zip or text file",
  uploadFailed: "Upload failed",
  removeAttachment: "Remove attachment",

  parameters: "Parameters",
  requiresApproval: "requires your approval",
  edit: "Edit",
  approve: "Approve",
  reject: "Reject",
  saveAndApprove: "Save & Approve",
  cancel: "Cancel",
  approvalJsonInvalid: "That is not valid JSON. Fix it before approving.",
  approvalExpiresIn(seconds) {
    const minutes = Math.floor(seconds / 60);
    return `Expires in ${minutes}:${String(seconds % 60).padStart(2, "0")}`;
  },
  approvalExpired: "This request expired, so nothing was changed. Ask again to run it.",
  dismiss: "Dismiss",
  status: {
    running: "Running",
    complete: "Complete",
    rejected: "Rejected",
    expired: "Expired",
    failed: "Failed",
  },

  chartEmpty: "No data to chart.",
  chartData: "Data",
  chartLabel: "Label",
  chartValue: "Value",
  chartOther: "Other",
  chartSeriesHidden(count) {
    return `${count} more ${count === 1 ? "series is" : "series are"} in the data table but not drawn.`;
  },
  gridSummary(total) {
    return `${total} ${total === 1 ? "result" : "results"}`;
  },
  gridWindow(from, to) {
    return `showing ${from}–${to}`;
  },
  gridEmpty: "No rows.",
};
