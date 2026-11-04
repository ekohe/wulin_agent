import {useEffect, useRef, useState} from "react";
import {strings} from "../strings";

const RESULT_MS = 3000;

// Copies the turn's reply and says whether that worked. assistant-ui's own Copy
// button drops clipboard failures silently, and the Clipboard API is missing
// outright on pages served over plain http from anywhere but localhost.
export function CopyButton({text}) {
  const [result, setResult] = useState(null);
  const timer = useRef(null);
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
      clearTimeout(timer.current);
    };
  }, []);

  async function copy() {
    let outcome = "copied";
    try {
      if (!navigator.clipboard) throw new Error("Clipboard API unavailable");
      await navigator.clipboard.writeText(text);
    } catch {
      outcome = "failed";
    }
    // A new turn can unmount the button while the clipboard write is pending.
    if (!mounted.current) return;

    setResult(outcome);
    clearTimeout(timer.current);
    // A failure stays up until the next try: it tells the user what to do.
    if (outcome === "copied") timer.current = setTimeout(() => setResult(null), RESULT_MS);
  }

  return (
    <div className="wulin-agent-turn-copy">
      <button type="button" className="wulin-agent-turn-copy__button" onClick={copy}>
        {strings.copy}
      </button>
      <span
        role="status"
        className={`wulin-agent-turn-copy__result${result === "failed" ? " wulin-agent-turn-copy__result--failed" : ""}`}
      >
        {result === "copied" ? strings.copied : result === "failed" ? strings.copyFailed : ""}
      </span>
    </div>
  );
}
