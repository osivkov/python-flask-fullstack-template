export type Status = { counter: number; version: string };

const baseUrl = (import.meta.env.VITE_API_BASE || "/api").replace(/\/$/, "");

async function request(path: string, options?: RequestInit): Promise<Status> {
  const response = await fetch(`${baseUrl}${path}`, options);
  if (!response.ok) {
    throw new Error(
      `API request failed (${response.status}). Please try again.`,
    );
  }
  return response.json();
}

export function getStatus(signal?: AbortSignal): Promise<Status> {
  return request("/status", { signal });
}

export function incrementCounter(): Promise<Status> {
  return request("/increment", { method: "POST" });
}
