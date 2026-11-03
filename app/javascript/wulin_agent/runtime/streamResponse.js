import {parseDataStream} from "../parseDataStream";
import {createTurnParts, findApprovedCall} from "../turnParts";

// Turns the server's data stream into assistant-ui message updates. A first
// run builds the message; a resume (after an approval) passes the message's
// existing tool calls, and what it yields is appended after them.
export async function* streamResponse(body, existingToolCalls = []) {
  const isResume = existingToolCalls.length > 0;
  const knownToolCallIds = new Set(
    existingToolCalls.map((part) => part.toolCallId)
  );
  // What this run adds, in arrival order. On a resume assistant-ui appends it
  // after the message's existing content.
  const turn = createTurnParts();
  let savedMessageId = null;

  function snapshot() {
    return {content: turn.content()};
  }

  function findCall(event) {
    const byId = (calls) =>
      calls.find((part) => part.toolCallId === event.toolCallId);

    if (isResume) {
      return (
        byId(existingToolCalls) ||
        byId(turn.toolCalls()) ||
        findApprovedCall(existingToolCalls)
      );
    }

    return (
      byId(turn.toolCalls()) || turn.toolCalls().find((part) => part.toolName === event.name)
    );
  }

  for await (const event of parseDataStream(body)) {
    switch (event.type) {
      case "text_delta":
        turn.appendText(event.content);
        yield snapshot();
        break;

      case "tool_call_start": {
        if (isResume && knownToolCallIds.has(event.toolCallId)) {
          break;
        }

        const exists = turn.toolCalls().find(
          (part) => part.toolCallId === event.toolCallId
        );

        if (!exists) {
          turn.addToolCall({
            type: "tool-call",
            toolCallId: event.toolCallId,
            toolName: event.toolName,
            args: {},
            argsText: "",
          });
          if (isResume) knownToolCallIds.add(event.toolCallId);
        }

        yield snapshot();
        break;
      }

      case "tool_call_args": {
        const calls = isResume
          ? [...existingToolCalls, ...turn.toolCalls()]
          : turn.toolCalls();
        const call =
          calls.find((part) => part.toolCallId === event.toolCallId) ||
          turn.toolCalls().at(-1);
        if (call) {
          call.args = event.arguments;
          call.argsText = JSON.stringify(event.arguments);
        }
        if (!isResume || !turn.isEmpty()) {
          yield snapshot();
        }
        break;
      }

      case "tool_result": {
        const call = findCall(event);

        if (event.result?.status === "approval_required") {
          if (call) {
            call.approval = {
              id: event.result.approval_token,
              expiresAt: event.result.approval_expires_at,
            };
            delete call.result;
          }

          yield {
            ...snapshot(),
            status: {type: "requires-action", reason: "tool-calls"},
          };
          return;
        }

        if (call) call.result = event.result;
        if (!isResume || !turn.isEmpty()) {
          yield snapshot();
        }
        break;
      }

      case "message_saved":
        savedMessageId = event.messageId;
        yield {...snapshot(), metadata: {custom: {messageId: savedMessageId}}};
        break;

      case "error":
        turn.startText(event.message);
        yield snapshot();
        return;
    }
  }
}
