import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, expect, it, vi } from "vitest";
import App from "./App";
import { getStatus, incrementCounter } from "./api";

vi.mock("./api", () => ({ getStatus: vi.fn(), incrementCounter: vi.fn() }));
afterEach(cleanup);

it("shows persisted data and updates it after a click", async () => {
  vi.mocked(getStatus).mockResolvedValue({ counter: 3, version: "test" });
  vi.mocked(incrementCounter).mockResolvedValue({
    counter: 4,
    version: "test",
  });
  render(<App />);
  await screen.findByText("3");
  fireEvent.click(screen.getByRole("button", { name: "Increment counter" }));
  await screen.findByText("4");
  expect(incrementCounter).toHaveBeenCalledOnce();
});

it("shows an error when the initial API request fails", async () => {
  vi.mocked(getStatus).mockRejectedValue(new Error("Cannot reach the API."));
  render(<App />);
  expect((await screen.findByRole("alert")).textContent).toBe(
    "Cannot reach the API.",
  );
  expect(screen.getByRole<HTMLButtonElement>("button").disabled).toBe(true);
});
