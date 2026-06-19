export function toAssistantUiMessages(apiMessages) {
    return apiMessages.map((msg) => {
      if (msg.role === "user") {
        return {
          role: "user",
          content: [{ type: "text", text: msg.content }],
        };
      }
  
      const { tool_calls = [], tool_results = [] } = msg.metadata ?? {};
      const parts = [];
  
      for (const tc of tool_calls) {
        const tr = tool_results.find((r) => r.id === tc.id);
        const result = tr?.result;
  
        const part = {
          type: "tool-call",
          toolCallId: tc.id,
          toolName: tc.name,
          args: tc.arguments ?? {},
          argsText: JSON.stringify(tc.arguments ?? {}),
        };
  
        if (result?.status === "approval_required") {
          part.approval = { id: result.approval_token };
        } else if (result) {
          part.result = result;
        }
  
        parts.push(part);
      }
  
      if (msg.content?.trim()) {
        parts.push({ type: "text", text: msg.content });
      }
  
      return { role: "assistant", content: parts };
    });
  }