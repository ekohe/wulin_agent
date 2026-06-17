import {useLocalRuntime} from "@assistant-ui/react";
import {wulinModelAdapter} from "./wulinModelAdapter";

export function useWulinAgentRuntime() {
  return useLocalRuntime(wulinModelAdapter);
}
