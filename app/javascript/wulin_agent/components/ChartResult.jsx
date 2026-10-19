import { ResponsiveContainer, BarChart, Bar, LineChart, Line,
    PieChart, Pie, Cell, XAxis, YAxis, Tooltip, Legend, CartesianGrid } from "recharts";

    // Used when the stylesheet has not defined the tokens.
    const FALLBACK_COLORS = ["#2563eb", "#16a34a", "#f59e0b", "#dc2626", "#7c3aed", "#0891b2"];

    function token(name, fallback = "") {
      const root = document.getElementById("wulin-agent-root");
      const value = root ? getComputedStyle(root).getPropertyValue(name).trim() : "";
      return value || fallback;
    }

    function chartColors() {
      return [1, 2, 3, 4, 5, 6].map((step, i) => token(`--wulin-agent-chart-${step}`, FALLBACK_COLORS[i]));
    }

    function themeColors() {
      return {
        text: token("--wulin-agent-text-muted", "#9e9e9e"),
        grid: token("--wulin-agent-border", "#e0e0e0"),
        bg: token("--wulin-agent-bg", "#fff"),
      };
    }

    function pivotSeries(data) {
        const names = [...new Set(data.map((d) => d.series).filter(Boolean))];
      
        if (names.length === 0) {
          return { rows: data, series: ["value"] };
        }
      
        const byLabel = new Map();
      
        for (const d of data) {
          const row = byLabel.get(d.label) ?? { label: d.label };
          row[d.series] = d.value;
          byLabel.set(d.label, row);
        }
      
        return {
          rows: [...byLabel.values()],
          series: names
        };
      }

    export function ChartResult({ result }) {
      const { type, title, data, x, y } = result;
      if (!data?.length) {
        return <p className="wulin-agent-chart__empty">No data to chart.</p>;
      }
      const { rows, series } = pivotSeries(data);
      const theme = themeColors();
      const colors = chartColors();
    
      function renderChart() {
        switch (type) {
          case "line":
            return (
              <LineChart data={rows} margin={{ bottom: 20, left: 10 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={theme.grid} />
                <XAxis dataKey="label" tick={{ fill: theme.text }} stroke={theme.grid}
                    label={x ? { value: x, position: "insideBottom", offset: -10, fill: theme.text } : undefined} />
                <YAxis tick={{ fill: theme.text }} stroke={theme.grid}
                    label={y ? { value: y, angle: -90, position: "insideLeft", fill: theme.text } : undefined} />
                <Tooltip contentStyle={{ background: theme.bg, border: `1px solid ${theme.grid}`, color: theme.text }} />
                <Legend verticalAlign="top" height={28} />
                {series.map((name, i) => (
                    <Line
                        key={name}
                        type="monotone"
                        dataKey={name}
                        stroke={colors[i % colors.length]}
                    />
                ))}
              </LineChart>
            );
    
          case "pie":
            return (
              <PieChart>
                <Tooltip contentStyle={{ background: theme.bg, border: `1px solid ${theme.grid}`, color: theme.text }} />
                <Legend />
                <Pie data={data} dataKey="value" nameKey="label" outerRadius={110} label>
                  {data.map((_, i) => (
                    <Cell key={i} fill={colors[i % colors.length]} />
                  ))}
                </Pie>
              </PieChart>
            );
    
          case "bar":
          default:
            return (
              <BarChart data={rows} margin={{ bottom: 20, left: 10 }}>
                <CartesianGrid strokeDasharray="3 3" stroke={theme.grid} />
                <XAxis dataKey="label" tick={{ fill: theme.text }} stroke={theme.grid}
                    label={x ? { value: x, position: "insideBottom", offset: -10, fill: theme.text } : undefined} />
                <YAxis tick={{ fill: theme.text }} stroke={theme.grid}
                    label={y ? { value: y, angle: -90, position: "insideLeft", fill: theme.text } : undefined} />
                <Tooltip contentStyle={{ background: theme.bg, border: `1px solid ${theme.grid}`, color: theme.text }} />
                <Legend verticalAlign="top" height={28} />
                {series.map((name, i) => (
                <Bar
                    key={name}
                    dataKey={name}
                    fill={colors[i % colors.length]}
                />
                ))}
              </BarChart>
            );
        }
      }
    
      return (
        <div className="wulin-agent-chart">
          {title && <p className="wulin-agent-chart__title">{title}</p>}
          <ResponsiveContainer width="100%" height={300}>
            {renderChart()}
          </ResponsiveContainer>
        </div>
      );
    }