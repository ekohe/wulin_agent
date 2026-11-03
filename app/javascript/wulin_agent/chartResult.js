// The categorical palette has this many slots (--wulin-agent-chart-1..6). A
// chart never reuses a color for a second series: identity would be lost.
export const CHART_SLOTS = 6;

export function isChartResult(result) {
  return (
    result &&
    typeof result === "object" &&
    result.display === "chart" &&
    Array.isArray(result.data)
  );
}

// Bar and line data, one row per label with a column per series. Points
// without a series form the single series "value". Series past the palette are
// left out of the drawing and counted in hiddenSeries; the table keeps them.
export function pivotSeries(data) {
  const names = [...new Set(data.map((point) => point.series).filter(Boolean))];
  if (names.length === 0) {
    return {rows: data.map(({label, value}) => ({label, value})), series: ["value"], allSeries: ["value"], hiddenSeries: 0};
  }

  const byLabel = new Map();
  for (const point of data) {
    const row = byLabel.get(point.label) ?? {label: point.label};
    row[point.series] = point.value;
    byLabel.set(point.label, row);
  }

  return {
    rows: [...byLabel.values()],
    series: names.slice(0, CHART_SLOTS),
    allSeries: names,
    hiddenSeries: Math.max(0, names.length - CHART_SLOTS),
  };
}

// Pie slices, largest first. Past the palette, the smallest fold into one
// "Other" slice so every slice keeps its own color; the table lists them all.
export function pieSlices(data, otherLabel) {
  const slices = data
    .map(({label, value}) => ({label, value: Number(value) || 0}))
    .sort((a, b) => b.value - a.value);
  if (slices.length <= CHART_SLOTS) return slices;

  const kept = slices.slice(0, CHART_SLOTS - 1);
  const rest = slices.slice(CHART_SLOTS - 1).reduce((sum, slice) => sum + slice.value, 0);
  return [...kept, {label: otherLabel, value: rest}];
}
