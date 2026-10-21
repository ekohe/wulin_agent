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
