import {useState} from "react";
import {
  ComposerPrimitive,
  MessagePrimitive,
  ThreadPrimitive,
  useAuiState,
} from "@assistant-ui/react";
import {ApprovalCard} from "./ApprovalCard";
import { GridResultTable } from "./GridResultTable";
import { isGridResult } from "../gridResult";
import { sendFeedback } from "../api";
import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { isChartResult } from "../chartResult";
import { ChartResult } from "./ChartResult";
import {ArchiveUploadButton} from "./ArchiveUploadButton";
import {ComposerSendButton} from "./ComposerSendButton";
import {MessageArchiveAttachment} from "./MessageArchiveAttachment";
import {PendingArchiveChip} from "./PendingArchiveChip";
import {lookupSentArchive} from "../sentMessageArchives";


function MessageFeedback() {
  const messageId = useAuiState((s) => s.message.metadata?.custom?.messageId);
  const rating0 = useAuiState((s) => s.message.metadata?.custom?.rating);
  const [rating, setRating] = useState(rating0 ?? null);

  const send = async (value) => {
    setRating(value);
    try {
      await sendFeedback(value, messageId);
    } catch (error) {
      console.error(error);
    }
  };

  return (
    <div className="wulin-agent-feedback">
      <button
        type="button"
        className={`wulin-agent-feedback__btn${rating === "up" ? " is-active" : ""}`}
        aria-label="Good response"
        onClick={() => send("up")}
      >
        <i className="material-icons" aria-hidden="true">thumb_up</i>
      </button>
      <button
        type="button"
        className={`wulin-agent-feedback__btn${rating === "down" ? " is-active" : ""}`}
        aria-label="Bad response"
        onClick={() => send("down")}
      >
        <i className="material-icons" aria-hidden="true">thumb_down</i>
      </button>
    </div>
  );
}

function UserMessage() {
  const archiveFromMeta = useAuiState((state) => state.message.metadata?.custom?.archive);
  const text = useAuiState((state) =>
    state.message.content
      .filter((part) => part.type === "text")
      .map((part) => part.text)
      .join("")
  );
  const archive = archiveFromMeta || lookupSentArchive(text, archiveFromMeta?.archive_id);

  return (
    <MessagePrimitive.Root className="wulin-agent-message wulin-agent-message--user">
      <div className="wulin-agent-message__role">User</div>
      <div className="wulin-agent-message__bubble">
        <MessageArchiveAttachment archive={archive} />
        <MessagePrimitive.Parts />
      </div>
    </MessagePrimitive.Root>
  );
}

function ToolFallback({toolName, args, result, approval, respondToApproval}) {
  const isPending =
    approval?.approved === undefined && approval?.resolution === undefined;
  const isExecuting = approval?.approved === true && result == null;
  const isRejected = approval?.approved === false;

  if (approval && isPending) {
    return (
      <ApprovalCard
        toolName={toolName}
        args={args}
        approval={approval}
        respondToApproval={respondToApproval}
      />
    );
  }

  let toolClass = "wulin-agent-tool";
  if (isRejected) {
    toolClass += " wulin-agent-tool--rejected";
  } else if (isExecuting) {
    toolClass += " wulin-agent-tool--executing";
  } else if (approval?.approved === true) {
    toolClass += " wulin-agent-tool--approved";
  }

  return (
    <details
      className={toolClass}
      open={isExecuting || isChartResult(result) || undefined}
    >
      <summary>
        {toolName}
        {isExecuting ? " — executing…" : ""}
      </summary>
      {args && Object.keys(args).length > 0 && (
        <pre>{JSON.stringify(args, null, 2)}</pre>
      )}
      {result != null && (
        isChartResult(result) ? (
          <ChartResult result={result} />
        ) : isGridResult(result) ? (
          <GridResultTable result={result} />
        ) : (
          <pre>{JSON.stringify(result, null, 2)}</pre>
        )
      )}
    </details>
  );
}

function AssistantText({text}) {
  return (
    <div className="wulin-agent-markdown">
      <Markdown remarkPlugins={[remarkGfm]}>{text}</Markdown>
    </div>
  );
}

function AssistantMessage() {
  return (
    <MessagePrimitive.Root className="wulin-agent-message wulin-agent-message--assistant">
      <div className="wulin-agent-message__role">Agent</div>
      <MessagePrimitive.Parts
        components={{
          Text: ({text}) =>
            text.startsWith("Error :") ? (
              <p className="wulin-agent-error">{text}</p>
            ) : (
              <AssistantText text={text} />
            ),
          tools: { Fallback: ToolFallback },
        }}
      />
      <MessageFeedback />
    </MessagePrimitive.Root>
  );
}

export function Thread() {
  return (
    <ThreadPrimitive.Root className="wulin-agent-thread">
      <ThreadPrimitive.Viewport className="wulin-agent-thread__viewport">
      <ThreadPrimitive.Empty>
        <div className="wulin-agent-thread__empty">Ask anything</div>
      </ThreadPrimitive.Empty>

        <ThreadPrimitive.Messages
          components={{UserMessage, AssistantMessage}}
        />
      </ThreadPrimitive.Viewport>

      <footer className="wulin-agent-thread__footer">
        <PendingArchiveChip />
        <ComposerPrimitive.Root className="wulin-agent-composer">
          <ArchiveUploadButton />
          <ComposerPrimitive.Input
            className="wulin-agent-composer__input"
            placeholder="Ex: How many people in the database ?"
          />
          <ComposerSendButton />
        </ComposerPrimitive.Root>
      </footer>
    </ThreadPrimitive.Root>
  );
}
