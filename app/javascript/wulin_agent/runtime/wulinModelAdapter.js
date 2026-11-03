import {getConversationId, runApproved, runRejected, sendMessage} from "../api";
import { getApprovalDraft, clearApprovalDraft } from "../approvalDrafts";
import {takePendingArchive} from "../pendingArchive";
import {registerSentArchive} from "../sentMessageArchives";
import {findApprovedCall, findRefusedCall} from "../turnParts";
import {streamResponse} from "./streamResponse";

function archiveFromLastUserMessage(messages) {
  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];
    if (message.role !== "user") continue;

    const archive = message.metadata?.custom?.archive;
    if (archive?.archive_id) return archive;
    break;
  }

  return null;
}

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
  async *run({messages, unstable_getMessage, abortSignal}) {
    const currentMessage = unstable_getMessage();
    const existingToolCalls = currentMessage.content.filter(
      (part) => part.type === "tool-call"
    );

    const approvedCall = findApprovedCall(existingToolCalls);
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

    const rejectedCall = findRefusedCall(existingToolCalls);
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
    const pendingArchive = takePendingArchive();
    const archiveFromMessage = archiveFromLastUserMessage(messages);
    const archive = pendingArchive || archiveFromMessage;
    const archiveId = archive?.archive_id;

    if (pendingArchive && !archiveFromMessage) {
      registerSentArchive(text, pendingArchive);
    }

    if (!text && !archiveId) {
      yield {content: [{type: "text", text: ""}]};
      return;
    }

    const {body} = await sendMessage(text, getConversationId(), {
      archiveId,
      signal: abortSignal,
    });
    yield* streamResponse(body);
  },
};
