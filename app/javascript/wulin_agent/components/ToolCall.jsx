import {ApprovalCard} from "./ApprovalCard";
import {GridResultTable} from "./GridResultTable";
import {isGridResult} from "../gridResult";
import {isChartResult} from "../chartResult";
import {ChartResult} from "./ChartResult";

export function ToolCall({toolName, args, result, approval, respondToApproval}) {
  const isPending =
    approval?.approved === undefined && approval?.resolution === undefined;
  const isExecuting = approval?.approved === true && result == null;
  const isRejected = approval?.approved === false;
  const hasArgs = args && Object.keys(args).length > 0;
  const showChart = isChartResult(result);
  const showGrid = !showChart && isGridResult(result);

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
    <div className={toolClass}>
      <details open={isExecuting || undefined}>
        <summary>
          {toolName}
          {isExecuting ? " — executing…" : ""}
        </summary>
        {hasArgs && (
          <details>
            <summary>Parameters</summary>
            <pre>{JSON.stringify(args, null, 2)}</pre>
          </details>
        )}
        {result != null && !showChart && !showGrid && (
          <pre>{JSON.stringify(result, null, 2)}</pre>
        )}
      </details>
      {showChart && <ChartResult result={result} />}
      {showGrid && <GridResultTable result={result} />}
    </div>
  );
}
