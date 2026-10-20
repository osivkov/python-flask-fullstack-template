import { afterEach, expect, it, vi } from "vitest";
import { getStatus, incrementCounter } from "./api";

afterEach(() => vi.unstubAllGlobals());

it("loads the current status from the same-origin API", async () => {
  const status = { counter: 3, version: "test" };
  const fetchMock = vi
    .fn()
    .mockResolvedValue(new Response(JSON.stringify(status)));
  vi.stubGlobal("fetch", fetchMock);
  await expect(getStatus()).resolves.toEqual(status);
  expect(fetchMock).toHaveBeenCalledWith("/api/status", { signal: undefined });
});

it("increments using POST", async () => {
  const fetchMock = vi
    .fn()
    .mockResolvedValue(new Response('{"counter":4,"version":"test"}'));
  vi.stubGlobal("fetch", fetchMock);
  await expect(incrementCounter()).resolves.toEqual({
    counter: 4,
    version: "test",
  });
  expect(fetchMock).toHaveBeenCalledWith("/api/increment", { method: "POST" });
});

it("reports unsuccessful HTTP responses", async () => {
  vi.stubGlobal(
    "fetch",
    vi.fn().mockResolvedValue(new Response(null, { status: 503 })),
  );
  await expect(getStatus()).rejects.toThrow("API request failed (503)");
});
