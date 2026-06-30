import { ResponsiveContainer, BarChart, Bar, LineChart, Line,
    PieChart, Pie, Cell, XAxis, YAxis, Tooltip, Legend, CartesianGrid } from "recharts";

    const COLORS = ["#2563eb", "#16a34a", "#f59e0b", "#dc2626", "#7c3aed", "#0891b2"];

    export function ChartResult({ result }) {
      const { type, title, data } = result;
      if (!data?.length) {
        return <p className="wulin-agent-chart__empty">No data to chart.</p>;
      }
    
      function renderChart() {
        switch (type) {
          case "line":
            return (
              <LineChart data={data}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="label" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Line type="monotone" dataKey="value" stroke={COLORS[0]} />
              </LineChart>
            );
    
          case "pie":
            return (
              <PieChart>
                <Tooltip />
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
              <BarChart data={data}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="label" />
                <YAxis />
                <Tooltip />
                <Legend />
                <Bar dataKey="value" fill={COLORS[0]} />
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