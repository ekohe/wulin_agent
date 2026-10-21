import {useState} from "react";
import {
  ComposerPrimitive,
  MessagePrimitive,
  ThreadPrimitive,
  useAuiState,
} from "@assistant-ui/react";
import {sendFeedback} from "../api";
import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";
import {ToolCall} from "./ToolCall";
import {IconButton} from "./IconButton";
import {ArchiveUploadButton} from "./ArchiveUploadButton";
import {ComposerSendButton} from "./ComposerSendButton";
import {MessageArchiveAttachment} from "./MessageArchiveAttachment";
import {PendingArchiveChip} from "./PendingArchiveChip";
import {lookupSentArchive} from "../sentMessageArchives";
import {useThreadBusy} from "../useThreadBusy";
import {strings} from "../strings";
import {useThreadRunning} from "../useThreadRunning";
import {useShowTurnFeedback, useShowTurnRole} from "../useShowTurnFeedback";
import {LoadingSpinner} from "./LoadingSpinner";


function MessageFeedback() {
  const show = useShowTurnFeedback();
  const messageId = useAuiState((s) => s.message.metadata?.custom?.messageId);
  const statusType = useAuiState((s) => s.message.status?.type);
  const rating0 = useAuiState((s) => s.message.metadata?.custom?.rating);
  const [rating, setRating] = useState(rating0 ?? null);
  const canFeedback = Boolean(messageId) && statusType !== "running";

  if (!show) return null;

  const send = async (value) => {
    if (!canFeedback) return;

    setRating(value);
    try {
      await sendFeedback(value, messageId);
    } catch (error) {
      console.error(error);
      setRating(rating0 ?? null);
    }
  };

  return (
    <div className="wulin-agent-feedback">
      <IconButton
        icon="thumb_up"
        label="Good response"
        className={rating === "up" ? "is-active" : undefined}
        disabled={!canFeedback}
        onClick={() => send("up")}
      />
      <IconButton
        icon="thumb_down"
        label="Bad response"
        className={rating === "down" ? "is-active" : undefined}
        disabled={!canFeedback}
        onClick={() => send("down")}
      />
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

function AssistantText({text}) {
  return (
    <div className="wulin-agent-markdown">
      <Markdown remarkPlugins={[remarkGfm]}>{text}</Markdown>
    </div>
  );
}

function AssistantMessage() {
  const showRole = useShowTurnRole();

  return (
    <MessagePrimitive.Root className="wulin-agent-message wulin-agent-message--assistant">
      {showRole && <div className="wulin-agent-message__role">Agent</div>}
      <MessagePrimitive.Parts
        components={{
          Text: ({text}) =>
            text.startsWith("Error :") ? (
              <p className="wulin-agent-error">{text}</p>
            ) : (
              <AssistantText text={text} />
            ),
          tools: { Fallback: ToolCall },
        }}
      />
      <MessageFeedback />
    </MessagePrimitive.Root>
  );
}

function ThreadWorkingIndicator({conversationStatus}) {
  const threadRunning = useThreadRunning();
  if (conversationStatus !== "running" && !threadRunning) return null;

  return (
    <div className="wulin-agent-thread__working" role="status" aria-live="polite">
      <LoadingSpinner />
      <span>Working…</span>
    </div>
  );
}

function ThreadComposer({conversationRunning}) {
  const threadBusy = useThreadBusy();
  const held = threadBusy || conversationRunning;

  return (
    <footer className="wulin-agent-thread__footer">
      <PendingArchiveChip />
      <ComposerPrimitive.Root className="wulin-agent-composer">
        <ArchiveUploadButton />
        <ComposerPrimitive.Input
          className="wulin-agent-composer__input"
          placeholder={strings.composerPlaceholder}
          submitMode={held ? "none" : "enter"}
          cancelOnEscape={false}
        />
        <ComposerSendButton held={held} />
      </ComposerPrimitive.Root>
    </footer>
  );
}

export function Thread({conversationStatus = "idle"}) {
  return (
    <ThreadPrimitive.Root className="wulin-agent-thread">
      <ThreadPrimitive.Viewport className="wulin-agent-thread__viewport">
      <ThreadPrimitive.Empty>
        <div className="wulin-agent-thread__empty">Ask anything</div>
      </ThreadPrimitive.Empty>

        <ThreadPrimitive.Messages
          components={{UserMessage, AssistantMessage}}
        />
        <ThreadWorkingIndicator conversationStatus={conversationStatus} />
      </ThreadPrimitive.Viewport>

      <ThreadComposer conversationRunning={conversationStatus === "running"} />
    </ThreadPrimitive.Root>
  );
}
