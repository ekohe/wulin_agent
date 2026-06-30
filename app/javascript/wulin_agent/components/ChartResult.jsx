import { ResponsiveContainer, BarChart, Bar, LineChart, Line,
    PieChart, Pie, Cell, XAxis, YAxis, Tooltip, Legend, CartesianGrid } from "recharts";

    const COLORS = ["#2563eb", "#16a34a", "#f59e0b", "#dc2626", "#7c3aed", "#0891b2"];

    function themeColors() {
      const root = document.getElementById("wulin-agent-root");
      const s = root ? getComputedStyle(root) : null;
      const v = (name, fb) => s?.getPropertyValue(name).trim() || fb;
      return {
        text: v("--wulin-agent-text-muted", "#9e9e9e"),
        grid: v("--wulin-agent-border", "#e0e0e0"),
        bg: v("--wulin-agent-bg", "#fff"),
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
                        stroke={COLORS[i % COLORS.length]}
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
                    <Cell key={i} fill={COLORS[i % COLORS.length]} />
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
                    fill={COLORS[i % COLORS.length]}
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