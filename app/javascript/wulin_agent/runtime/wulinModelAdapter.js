import {getConversationId, sendMessage} from "../api";
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
/** @type {import("@assistant-ui/react").ChatModelAdapter} */
export const wulinModelAdapter = {
  async *run({messages, abortSignal}) {
    const text = lastUserText(messages);

    if (!text) {
      yield {content: [{type: "text", text: ""}]};
      return;
    }

    const {body} = await sendMessage(text, getConversationId(), {
      signal: abortSignal,
    });

    const toolCalls = [];
    let accumulatedText = "";

    function snapshot() {
      return {
        content: [
          ...toolCalls,
          ...(accumulatedText
            ? [{type: "text", text: accumulatedText}]
            : [])
        ]
      };
    }

    for await (const event of parseDataStream(body)) {
      switch (event.type) {

        case "text_delta":
          accumulatedText += event.content;

          yield snapshot();
          break;


        case "tool_call_start":
          toolCalls.push({
            type: "tool-call",
            toolCallId: event.toolCallId,
            toolName: event.toolName,
            args: {},
            argsText: "",
          });

          yield snapshot();
          break;


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
          const call = toolCalls.find(
            (tc) => tc.toolCallId === event.toolCallId
          );
          if (call) call.result = event.result;

          yield snapshot();
          break;
        }


        case "error":
          throw new Error(event.message);
      }
    }
  },
};
