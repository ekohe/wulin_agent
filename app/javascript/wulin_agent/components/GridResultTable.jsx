import { isGridResult, gridRows } from "../gridResult";

function formatCell(value) {
  if (value == null || value === "") return "—";
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
}

export function GridResultTable({ result }) {
  if (!isGridResult(result)) return null;

  const { columns, total, offset = 0, rows } = result;
  const data = gridRows(result);
  const from = rows.length ? offset + 1 : 0;
  const to = offset + rows.length;

  return (
    <div className="wulin-agent-grid-result">
      <p className="wulin-agent-grid-result__meta">
        {total} result{total > 1 ? "s" : ""}
        {rows.length > 0 && ` · affichage ${from}–${to}`}
      </p>
      {rows.length === 0 ? (
        <p className="wulin-agent-grid-result__empty">0 lines.</p>
      ) : (
        <div className="wulin-agent-grid-result__scroll">
          <table className="wulin-agent-grid-result__table">
            <thead>
              <tr>
                {columns.map((col) => (
                  <th key={col.name}>{col.label || col.name}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {data.map((row, rowIndex) => (
                <tr key={rowIndex}>
                  {row.map((cell, colIndex) => (
                    <td key={colIndex}>{formatCell(cell)}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}