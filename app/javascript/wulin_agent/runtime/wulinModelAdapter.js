import {getConversationId, runApproved, runRejected, sendMessage} from "../api";
import {parseDataStream} from "../parseDataStream";
import { getApprovalDraft, clearApprovalDraft } from "../approvalDrafts";

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
  const knownToolCallIds = new Set(
    existingToolCalls.map((part) => part.toolCallId)
  );
  const toolCalls = [];
  const newToolCalls = [];
  let accumulatedText = "";
  let savedMessageId = null;

  function allCalls() {
    return isResume ? newToolCalls : toolCalls;
  }

  function snapshot() {
    const calls = allCalls();
    const content = [
      ...calls,
      ...(accumulatedText
        ? [{type: "text", text: accumulatedText}]
        : []),
    ];
    return {content};
  }

  function findCall(event) {
    const byId = (calls) =>
      calls.find((part) => part.toolCallId === event.toolCallId);

    if (isResume) {
      return (
        byId(existingToolCalls) ||
        byId(newToolCalls) ||
        existingToolCalls.find(
          (part) => part.approval?.approved === true && part.result === undefined
        )
      );
    }

    return (
      byId(toolCalls) || toolCalls.find((part) => part.toolName === event.name)
    );
  }

  function shouldYieldResumeUpdate() {
    return newToolCalls.length > 0 || accumulatedText;
  }

  for await (const event of parseDataStream(body)) {
    switch (event.type) {
      case "text_delta":
        accumulatedText += event.content;
        yield snapshot();
        break;

      case "tool_call_start": {
        if (isResume && knownToolCallIds.has(event.toolCallId)) {
          break;
        }

        const calls = allCalls();
        const exists = calls.find(
          (part) => part.toolCallId === event.toolCallId
        );

        if (!exists) {
          const part = {
            type: "tool-call",
            toolCallId: event.toolCallId,
            toolName: event.toolName,
            args: {},
            argsText: "",
          };
          calls.push(part);
          if (isResume) knownToolCallIds.add(event.toolCallId);
        }

        yield snapshot();
        break;
      }

      case "tool_call_args": {
        const calls = isResume
          ? [...existingToolCalls, ...newToolCalls]
          : toolCalls;
        const call =
          calls.find((part) => part.toolCallId === event.toolCallId) ||
          allCalls()[allCalls().length - 1];
        if (call) {
          call.args = event.arguments;
          call.argsText = JSON.stringify(event.arguments);
        }
        if (!isResume || shouldYieldResumeUpdate()) {
          yield snapshot();
        }
        break;
      }

      case "tool_result": {
        const call = findCall(event);

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
        if (!isResume || shouldYieldResumeUpdate()) {
          yield snapshot();
        }
        break;
      }

      case "message_saved":
        savedMessageId = event.messageId;
        yield {...snapshot(), metadata: {custom: {messageId: savedMessageId}}};
        break;

      case "error":
        accumulatedText += `\n\nErreur : ${event.message}`;
        yield snapshot();
        return;
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
      const token = approvedCall.approval.id;
      const params =
        getApprovalDraft(token) ?? approvedCall.args;
      approvedCall.args = params;
      approvedCall.argsText = JSON.stringify(params);
      const {body} = await runApproved({
        token,
        params,
        signal: abortSignal,
      });
      clearApprovalDraft(token);

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
