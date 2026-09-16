function buildApprovalResolutions(apiMessages) {
  const resolutions = new Map();

  apiMessages.forEach((msg, msgIndex) => {
    if (msg.role !== "assistant") return;

    const toolCalls = msg.metadata?.tool_calls ?? [];
    const toolResults = msg.metadata?.tool_results ?? [];

    for (const tc of toolCalls) {
      const tr = toolResults.find((r) => r.id === tc.id);
      const result = tr?.result;
      if (result?.status !== "approval_required") continue;

      const token = result.approval_token;
      const later = apiMessages.slice(msgIndex + 1);

      const success = later
        .flatMap((m) => m.metadata?.tool_results ?? [])
        .find(
          (r) =>
            r.name === tc.name &&
            r.result?.status !== "approval_required" &&
            r.result?.status !== "rejected"
        );

      if (success) {
        resolutions.set(token, {approved: true, result: success.result});
        continue;
      }

      if (later.some((m) => m.role === "assistant")) {
        resolutions.set(token, {approved: false});
      } else {
        resolutions.set(token, {approved: false, resolution: "expired"});
      }
    }
  });

  return resolutions;
}

export function toAssistantUiMessages(apiMessages) {
  const approvalResolutions = buildApprovalResolutions(apiMessages);

  return apiMessages.map((msg) => {
    if (msg.role === "user") {
      const metadata = msg.metadata ?? {};
      const archive = metadata.archive_id
        ? {
            archive_id: metadata.archive_id,
            filename: metadata.archive_filename || "archive.zip",
            file_count: metadata.archive_file_count,
            inject_mode: metadata.inject_mode,
            inject_message: metadata.inject_message,
          }
        : null;

      return {
        role: "user",
        content: [{type: "text", text: msg.content}],
        ...(archive
          ? {metadata: {custom: {archive}}}
          : {}),
      };
    }

    const {tool_calls = [], tool_results = []} = msg.metadata ?? {};
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
        const resolved = approvalResolutions.get(result.approval_token);
        if (resolved?.approved) {
          part.approval = {approved: true};
          if (resolved.result) part.result = resolved.result;
        } else {
          part.approval = {
            approved: false,
            ...(resolved?.resolution ? {resolution: resolved.resolution} : {}),
          };
        }
      } else if (result?.status === "rejected") {
        part.approval = {approved: false};
        part.result = result;
      } else if (result) {
        part.result = result;
      }

      parts.push(part);
    }

    if (msg.content?.trim()) {
      parts.push({type: "text", text: msg.content});
    }

    return {
      role: "assistant",
      content: parts,
      metadata: { custom: { rating: msg.rating ?? null, messageId: msg.id ?? null } },
    };
  });
}
