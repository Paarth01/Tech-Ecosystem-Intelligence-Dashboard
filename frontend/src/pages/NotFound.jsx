import { Link } from "react-router-dom";
import { Empty } from "../components/PageState";

export default function NotFound() {
  return <Empty title="Page not found">That page doesn&apos;t exist. <Link to="/">Back to the dashboard</Link>.</Empty>;
}
