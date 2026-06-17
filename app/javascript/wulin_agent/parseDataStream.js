export async function* parseDataStream(readableStream) {
  const reader = readableStream.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const {done, value} = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, {stream: true});

    let newlineIndex;
    while ((newlineIndex = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, newlineIndex).trim();
      buffer = buffer.slice(newlineIndex + 1);

      if (!line || line === "[DONE]") continue;

      const colon = line.indexOf(":");
      if (colon === -1) continue;

      const prefix = line.slice(0, colon);
      const payload = line.slice(colon + 1);
      console.log("RAW STREAM LINE:", line);

      try {
        switch (prefix) {
          case "0":
            yield {type: "text_delta", content: JSON.parse(payload)};
            break;
          case "b":
            yield {type: "tool_call_start", ...JSON.parse(payload)};
            break;
          case "c":
            yield {type: "tool_call_args", arguments: JSON.parse(payload)};
            break;
          case "a":
            yield {type: "tool_result", ...JSON.parse(payload)};
            break;
          case "d":
            yield {type: "done", ...JSON.parse(payload)};
            break;
          case "3":
            yield {type: "error", message: JSON.parse(payload)};
            break;
        }
      } catch (e) {
        console.warn("wulin_agent: failed to parse stream line", line, e);
      }
    }
  }
}
