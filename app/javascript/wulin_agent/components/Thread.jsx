import {
  ComposerPrimitive,
  MessagePrimitive,
  ThreadPrimitive,
} from "@assistant-ui/react";

function UserMessage() {
  return (
    <MessagePrimitive.Root className="wulin-agent-message wulin-agent-message--user">
      <MessagePrimitive.Parts />
    </MessagePrimitive.Root>
  );
}

function ToolFallback({toolName, args, result, approval, respondToApproval}) {
  if (
    approval &&
    approval.approved === undefined &&
    approval.resolution === undefined
  ) {
    return (
      <div className="wulin-agent-approval">
        <p className="wulin-agent-approval__title">
          <span className="wulin-agent-approval__tool">{toolName}</span>
          {" "}requires your approval
        </p>
        {args && Object.keys(args).length > 0 && (
          <pre className="wulin-agent-approval__args">
            {JSON.stringify(args, null, 2)}
          </pre>
        )}
        <div className="wulin-agent-approval__actions">
          <button
            type="button"
            className="wulin-agent-approval__approve"
            onClick={() => respondToApproval({approved: true})}
          >
            Approve
          </button>
          <button
            type="button"
            className="wulin-agent-approval__reject"
            onClick={() =>
              respondToApproval({approved: false, reason: "User declined"})
            }
          >
            Reject
          </button>
        </div>
      </div>
    );
  }

  return (
    <details className="wulin-agent-tool">
      <summary>{toolName}</summary>
      {args && Object.keys(args).length > 0 && (
        <pre>{JSON.stringify(args, null, 2)}</pre>
      )}
      {result != null && (
        <pre>{JSON.stringify(result, null, 2)}</pre>
      )}
    </details>
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
              <p>{text}</p>
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

        <ThreadPrimitive.ViewportFooter className="wulin-agent-thread__footer">
          <ComposerPrimitive.Root className="wulin-agent-composer">
            <ComposerPrimitive.Input
              className="wulin-agent-composer__input"
              placeholder="Ex: How many people in the database ?"
            />
            <ComposerPrimitive.Send className="wulin-agent-composer__send">
              Send
            </ComposerPrimitive.Send>
          </ComposerPrimitive.Root>
        </ThreadPrimitive.ViewportFooter>
      </ThreadPrimitive.Viewport>
    </ThreadPrimitive.Root>
  );
}
