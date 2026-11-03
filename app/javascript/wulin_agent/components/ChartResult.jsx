import {
  ResponsiveContainer, BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, Tooltip, Legend, CartesianGrid,
} from "recharts";
import {CHART_SLOTS, pieSlices, pivotSeries} from "../chartResult";
import {strings} from "../strings";

// The panel's tokens, read where the chart renders: always inside
// #wulin-agent-root, whose stylesheet defines every one of them.
function tokens(element) {
  const style = getComputedStyle(element);
  const read = (name) => style.getPropertyValue(name).trim();
  return {
    series: Array.from({length: CHART_SLOTS}, (_, i) => read(`--wulin-agent-chart-${i + 1}`)),
    text: read("--wulin-agent-text-muted"),
    grid: read("--wulin-agent-border"),
    bg: read("--wulin-agent-bg"),
  };
}

function formatValue(value) {
  return value == null || value === "" ? "—" : String(value);
}

// Every value the chart was given, for readers who cannot see or hover it.
function ChartTable({columns, rows}) {
  return (
    <details className="wulin-agent-chart__data">
      <summary>{strings.chartData}</summary>
      <div className="wulin-agent-grid-result__scroll">
        <table className="wulin-agent-grid-result__table">
          <thead>
            <tr>{columns.map((column) => <th key={column.key} scope="col">{column.label}</th>)}</tr>
          </thead>
          <tbody>
            {rows.map((row, i) => (
              <tr key={i}>
                {columns.map((column) => <td key={column.key}>{formatValue(row[column.key])}</td>)}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </details>
  );
}

function axisProps(theme, label, vertical) {
  return {
    // Room at both ends so a line's first and last markers are not clipped.
    ...(vertical ? {} : {padding: {left: 12, right: 12}}),
    tick: {fill: theme.text},
    stroke: theme.grid,
    label: label
      ? (vertical
        ? {value: label, angle: -90, position: "insideLeft", fill: theme.text}
        : {value: label, position: "insideBottom", offset: -10, fill: theme.text})
      : undefined,
  };
}

function pieChart(data, theme, animate, tooltipStyle) {
  const slices = pieSlices(data, strings.chartOther);
  return (
    <PieChart>
      <Tooltip contentStyle={tooltipStyle} />
      <Legend />
      <Pie data={slices} dataKey="value" nameKey="label" outerRadius={110}
        stroke={theme.bg} strokeWidth={2} isAnimationActive={animate}>
        {slices.map((slice, i) => <Cell key={i} fill={theme.series[i]} />)}
      </Pie>
    </PieChart>
  );
}

function seriesChart(type, rows, series, {x, y}, theme, animate, tooltipStyle) {
  const legend = series.length > 1 && <Legend verticalAlign="top" height={28} />;
  const grid = <CartesianGrid vertical={false} stroke={theme.grid} />;
  const axes = (
    <>
      <XAxis dataKey="label" {...axisProps(theme, x, false)} />
      <YAxis {...axisProps(theme, y, true)} />
    </>
  );

  if (type === "line") {
    return (
      <LineChart data={rows} margin={{bottom: 20, left: 10}}>
        {grid}{axes}
        <Tooltip contentStyle={tooltipStyle} />
        {legend}
        {series.map((name, i) => (
          <Line key={name} type="monotone" dataKey={name} stroke={theme.series[i]} strokeWidth={2}
            dot={{r: 4, fill: theme.series[i], stroke: theme.bg, strokeWidth: 2}} isAnimationActive={animate} />
        ))}
      </LineChart>
    );
  }

  return (
    <BarChart data={rows} margin={{bottom: 20, left: 10}}>
      {grid}{axes}
      <Tooltip contentStyle={tooltipStyle} cursor={{fill: theme.grid, opacity: 0.4}} />
      {legend}
      {series.map((name, i) => (
        <Bar key={name} dataKey={name} fill={theme.series[i]} maxBarSize={24} radius={[4, 4, 0, 0]}
          isAnimationActive={animate} />
      ))}
    </BarChart>
  );
}

export function ChartResult({result}) {
  const {type, title, data, x, y} = result;
  if (!data?.length) {
    return <p className="wulin-agent-chart__empty">{strings.chartEmpty}</p>;
  }

  const theme = tokens(document.getElementById("wulin-agent-root"));
  const animate = !window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const tooltipStyle = {background: theme.bg, border: `1px solid ${theme.grid}`, color: theme.text};
  const labelColumn = {key: "label", label: x || strings.chartLabel};

  let chart, table, hiddenSeries = 0;
  if (type === "pie") {
    chart = pieChart(data, theme, animate, tooltipStyle);
    table = {columns: [labelColumn, {key: "value", label: y || strings.chartValue}], rows: data};
  } else {
    const pivot = pivotSeries(data);
    chart = seriesChart(type, pivot.rows, pivot.series, {x, y}, theme, animate, tooltipStyle);
    hiddenSeries = pivot.hiddenSeries;
    table = {
      columns: [
        labelColumn,
        ...pivot.allSeries.map((name) => ({key: name, label: name === "value" ? (y || strings.chartValue) : name})),
      ],
      rows: pivot.rows,
    };
  }

  return (
    <div className="wulin-agent-chart">
      {title && <p className="wulin-agent-chart__title">{title}</p>}
      <ResponsiveContainer width="100%" height={300}>{chart}</ResponsiveContainer>
      {hiddenSeries > 0 && <p className="wulin-agent-chart__note">{strings.chartSeriesHidden(hiddenSeries)}</p>}
      <ChartTable columns={table.columns} rows={table.rows} />
    </div>
  );
}
