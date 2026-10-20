import { useEffect, useState } from "react";
import { getStatus, incrementCounter, type Status } from "./api";

export default function App() {
  const [status, setStatus] = useState<Status | null>(null);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const controller = new AbortController();
    getStatus(controller.signal)
      .then(setStatus)
      .catch((cause: unknown) => {
        if (!controller.signal.aborted) {
          setError(
            cause instanceof Error ? cause.message : "Cannot reach the API.",
          );
        }
      });
    return () => controller.abort();
  }, []);

  async function increment() {
    setBusy(true);
    setError("");
    try {
      setStatus(await incrementCounter());
    } catch (cause) {
      setError(
        cause instanceof Error ? cause.message : "Cannot update the counter.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <main>
      <h1>Flask Full-stack Template</h1>
      <p>React frontend · Flask API · PostgreSQL</p>
      <dl>
        <dt>API version</dt>
        <dd>{status?.version ?? "—"}</dd>
        <dt>Counter</dt>
        <dd>{status?.counter ?? "—"}</dd>
      </dl>
      <button disabled={!status || busy} onClick={increment}>
        {busy ? "Saving…" : "Increment counter"}
      </button>
      {!status && !error && <p role="status">Loading…</p>}
      {error && <p role="alert">{error}</p>}
      <p>
        The counter is stored in PostgreSQL and survives container replacement.
      </p>
    </main>
  );
}
