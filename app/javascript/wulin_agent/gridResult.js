export function isGridResult(result) {
    return (
      result &&
      typeof result === "object" &&
      result.display === "grid" &&
      Array.isArray(result.rows) &&
      Array.isArray(result.columns)
    );
  }
  
  export function gridRows(result) {
    const { columns, rows } = result;
    return rows.map((row) =>
      columns.map((col, i) => row[i] ?? "")
    );
  }