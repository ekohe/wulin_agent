// The content of an assistant message in the order it arrived: text segments
// and the tool calls between them. A turn makes one tool call per model round,
// so text written before, between and after the calls is several segments.
// Tool call parts are kept by identity (results are written onto them as they
// arrive); text parts are copied on every read so each snapshot is new.
export function createTurnParts() {
  const parts = [];

  return {
    appendText(text) {
      if (!text) return;
      const last = parts.at(-1);
      if (last?.type === "text") last.text += text;
      else parts.push({type: "text", text});
    },

    // A segment of its own, such as an error after whatever the turn wrote.
    startText(text) {
      if (text) parts.push({type: "text", text});
    },

    addToolCall(part) {
      parts.push(part);
    },

    toolCalls() {
      return parts.filter((part) => part.type === "tool-call");
    },

    isEmpty() {
      return parts.length === 0;
    },

    content() {
      return parts.map((part) => (part.type === "text" ? {type: "text", text: part.text} : part));
    },
  };
}

// A call the user approved that has not run yet.
export function findApprovedCall(toolCalls) {
  return toolCalls.find((part) => part.approval?.approved === true && part.result === undefined);
}

// A call the user refused just now. It still carries the approval id, which
// calls read back from history do not (messageMapper leaves it out);
// assistant-ui stores its own { error } result on a refused call, so the
// result cannot tell the two apart.
export function findRefusedCall(toolCalls) {
  return toolCalls.findLast((part) => part.approval?.approved === false && part.approval?.id);
}
