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

    let accumulated = "";

    for await (const event of parseDataStream(body)) {
      if (event.type === "text_delta") {
        accumulated += event.content;
        yield {content: [{type: "text", text: accumulated}]};
      }

      if (event.type === "error") {
        throw new Error(event.message);
      }
    }
  },
};
