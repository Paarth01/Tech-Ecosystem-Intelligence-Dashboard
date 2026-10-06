import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

// Renders a comparison. Raw HTML is not allowed; only Markdown formatting is shown.
export default function Markdown({ children }) {
  return (
    <div className="prose">
      <div className="table-scroll">
        <ReactMarkdown
          remarkPlugins={[remarkGfm]}
          components={{ a: (props) => <a {...props} target="_blank" rel="noopener noreferrer" /> }}
        >
          {children}
        </ReactMarkdown>
      </div>
    </div>
  );
}
