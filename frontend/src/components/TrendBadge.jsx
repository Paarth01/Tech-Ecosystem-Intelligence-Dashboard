// Shows how a topic's score changed since yesterday. "Flat" and unknown changes show nothing.
export default function TrendBadge({ trend }) {
  if (!trend) return null;
  if (trend.label === "new") return <span className="trend trend-new" title="Wasn't in yesterday's ranking">New</span>;
  if (trend.label === "up") return <span className="trend trend-up" title="Score change since yesterday">↑ {trend.percent}%</span>;
  if (trend.label === "down") return <span className="trend trend-down" title="Score change since yesterday">↓ {Math.abs(trend.percent)}%</span>;
  return null;
}
