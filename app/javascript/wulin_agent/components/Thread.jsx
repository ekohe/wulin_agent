import {
  ComposerPrimitive,
  MessagePrimitive,
  ThreadPrimitive,
} from "@assistant-ui/react";
import {ApprovalCard} from "./ApprovalCard";
import { GridResultTable } from "./GridResultTable";
import { isGridResult } from "../gridResult";
import { MarkdownTextPrimitive } from "@assistant-ui/react-markdown";
import remarkGfm from "remark-gfm";

function UserMessage() {
  return (
    <MessagePrimitive.Root className="wulin-agent-message wulin-agent-message--user">
      <MessagePrimitive.Parts />
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
    <details className={toolClass} open={isExecuting || undefined}>
      <summary>
        {toolName}
        {isExecuting ? " — executing…" : ""}
      </summary>
      {args && Object.keys(args).length > 0 && (
        <pre>{JSON.stringify(args, null, 2)}</pre>
      )}
      {result != null && (
        isGridResult(result) ? (
          <GridResultTable result={result} />
        ) : (
          <pre>{JSON.stringify(result, null, 2)}</pre>
        )
      )}
    </details>
  );
}

function AssistantText() {
  return (
    <MarkdownTextPrimitive
      remarkPlugins={[remarkGfm]}
      className="wulin-agent-markdown"
    />
  );
}

function AssistantMessage() {
  return (
    <MessagePrimitive.Root className="wulin-agent-message wulin-agent-message--assistant">
      <MessagePrimitive.Parts
        components={{
          Text: ({text}) =>
            text.startsWith("Error :") ? (
              <p className="wulin-agent-error">{text}</p>
            ) : (
              <AssistantText />
            ),
          tools: { Fallback: ToolFallback },
        }}
      />
    </MessagePrimitive.Root>
  );
}

export function Thread() {
  return (
    <ThreadPrimitive.Root className="wulin-agent-thread">
      <ThreadPrimitive.Viewport className="wulin-agent-thread__viewport">
        <ThreadPrimitive.Empty className="wulin-agent-thread__empty">
          Ask a question…
        </ThreadPrimitive.Empty>

        <ThreadPrimitive.Messages
          components={{UserMessage, AssistantMessage}}
        />
      </ThreadPrimitive.Viewport>

      <footer className="wulin-agent-thread__footer">
        <ComposerPrimitive.Root className="wulin-agent-composer">
          <ComposerPrimitive.Input
            className="wulin-agent-composer__input"
            placeholder="Ex: How many people in the database ?"
          />
          <ComposerPrimitive.Send className="wulin-agent-composer__send">
            Send
          </ComposerPrimitive.Send>
        </ComposerPrimitive.Root>
      </footer>
    </ThreadPrimitive.Root>
  );
}
