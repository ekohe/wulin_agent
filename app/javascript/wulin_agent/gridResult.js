export function isGridResult(result) {
  return (
    result &&
    typeof result === "object" &&
    result.display === "grid" &&
    Array.isArray(result.rows) &&
    Array.isArray(result.columns)
  );
}

function cellValue(row, col, index) {
  if (row == null) return "";
  if (Array.isArray(row)) return row[index] ?? "";

  if (typeof row === "object") {
    const name = col?.name ?? col;
    if (name == null) return "";
    return row[name] ?? row[String(name)] ?? "";
  }

  return "";
}

export function gridRows(result) {
  const { columns, rows } = result;
  return rows.map((row) => columns.map((col, i) => cellValue(row, col, i)));
}
