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

function ToolFallback({toolName, args, result}) {
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
        components={{tools: {Fallback: ToolFallback}}}
      />
    </MessagePrimitive.Root>
  );
}

export function Thread() {
  return (
    <ThreadPrimitive.Root className="wulin-agent-thread">
      <ThreadPrimitive.Viewport className="wulin-agent-thread__viewport">
        <ThreadPrimitive.Empty className="wulin-agent-thread__empty">
          Pose une question sur la grille…
        </ThreadPrimitive.Empty>

        <ThreadPrimitive.Messages
          components={{UserMessage, AssistantMessage}}
        />

        <ThreadPrimitive.ViewportFooter className="wulin-agent-thread__footer">
          <ComposerPrimitive.Root className="wulin-agent-composer">
            <ComposerPrimitive.Input
              className="wulin-agent-composer__input"
              placeholder="Ex: Combien de personnes ?"
            />
            <ComposerPrimitive.Send className="wulin-agent-composer__send">
              Envoyer
            </ComposerPrimitive.Send>
          </ComposerPrimitive.Root>
        </ThreadPrimitive.ViewportFooter>
      </ThreadPrimitive.Viewport>
    </ThreadPrimitive.Root>
  );
}
