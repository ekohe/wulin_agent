import {WulinAgentProvider} from "./WulinAgentProvider";
import {Thread} from "./Thread";

export function AgentApp() {
  return (
    <WulinAgentProvider>
      <div className="wulin-agent-panel">
        <header className="wulin-agent-panel__header">
          <h2 className="wulin-agent-panel__title">Wulin Agent</h2>
        </header>
        <Thread />
      </div>
    </WulinAgentProvider>
  );
}
