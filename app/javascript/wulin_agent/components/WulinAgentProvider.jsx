import {AssistantRuntimeProvider} from "@assistant-ui/react";
import {useWulinAgentRuntime} from "../runtime/useWulinAgentRuntime";

export function WulinAgentProvider({children}) {
  const runtime = useWulinAgentRuntime();

  return (
    <AssistantRuntimeProvider runtime={runtime}>
      {children}
    </AssistantRuntimeProvider>
  );
}
