export function isChartResult(result) {
    return (
      result &&
      typeof result === "object" &&
      result.display === "chart" &&
      Array.isArray(result.data)
    );
  }