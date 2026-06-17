import {getConversationId, runApproved, runRejected, sendMessage} from "../api";
import {parseDataStream} from "../parseDataStream";

function lastUserText(messages) {
  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];
    if (message.role !== "user") continue;

    return message.content
      .filter((part) => part.type === "text")
      .map((part) => part.text)
      .join("");
  }

  return "";
}

async function* streamResponse(body, existingToolCalls = []) {
  const isResume = existingToolCalls.length > 0;
  const toolCalls = [];
  let accumulatedText = "";

  function snapshot() {
    if (isResume) {
      return {
        content: accumulatedText
          ? [{type: "text", text: accumulatedText}]
          : [],
      };
    }
    return {
      content: [
        ...toolCalls,
        ...(accumulatedText
          ? [{type: "text", text: accumulatedText}]
          : []),
      ],
    };
  }

  for await (const event of parseDataStream(body)) {
    switch (event.type) {
      case "text_delta":
        accumulatedText += event.content;
        yield snapshot();
        break;

      case "tool_call_start": {
        const exists = toolCalls.find(
          (t) => t.toolCallId === event.toolCallId
        );
      
        if (!exists) {
          toolCalls.push({
            type: "tool-call",
            toolCallId: event.toolCallId,
            toolName: event.toolName,
            args: {},
            argsText: "",
          });
        }
      
        yield snapshot();
        break;
      }

      case "tool_call_args": {
        const call = toolCalls[toolCalls.length - 1];
        if (call) {
          call.args = event.arguments;
          call.argsText = JSON.stringify(event.arguments);
        }
        yield snapshot();
        break;
      }

      case "tool_result": {
        const call = isResume
          ? existingToolCalls.find((tc) => tc.toolCallId === event.toolCallId) ||
            existingToolCalls.find(
              (p) => p.approval?.approved === true && p.result === undefined
            )
          : toolCalls.find((tc) => tc.toolCallId === event.toolCallId) ||
            toolCalls.find((tc) => tc.toolName === event.name);
      
        if (event.result?.status === "approval_required") {
          if (call) {
            call.approval = {id: event.result.approval_token};
            delete call.result;
          }
      
          yield {
            ...snapshot(),
            status: {type: "requires-action", reason: "tool-calls"},
          };
          return;
        }
      
        if (call) call.result = event.result;
        yield snapshot();
        break;
      }

      case "error":
        throw new Error(event.message);
    }
  }
}

/** @type {import("@assistant-ui/react").ChatModelAdapter} */
export const wulinModelAdapter = {
  async *run({messages, unstable_getMessage, abortSignal}) {
    const currentMessage = unstable_getMessage();
    const existingToolCalls = currentMessage.content.filter(
      (part) => part.type === "tool-call"
    );

    const approvedCall = existingToolCalls.find(
      (part) =>
        part.approval?.approved === true && part.result === undefined
    );
    if (approvedCall) {
      const {body} = await runApproved({
        token: approvedCall.approval.id,
        signal: abortSignal,
      });
      yield* streamResponse(body, existingToolCalls);
      return;
    }

    const rejectedCall = existingToolCalls.find(
      (part) => part.approval?.approved === false
    );
    if (rejectedCall) {
      const {body} = await runRejected({
        token: rejectedCall.approval.id,
        reason: rejectedCall.approval.reason,
        signal: abortSignal,
      });
      yield* streamResponse(body, existingToolCalls);
      return;
    }

    const text = lastUserText(messages);
    if (!text) {
      yield {content: [{type: "text", text: ""}]};
      return;
    }

    const {body} = await sendMessage(text, getConversationId(), {
      signal: abortSignal,
    });
    yield* streamResponse(body);
  },
};
