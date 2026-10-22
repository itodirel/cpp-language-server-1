import { joinSession } from "@github/copilot-sdk/extension";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

// Session-start hooks arrive after the first prompt, too late for eager LSP startup.
const session = await joinSession();
if (process.platform === "win32") {
  const metadata = await session.rpc.metadata.snapshot();
  const id = session.sessionId.toLowerCase();
  if (!/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(id) ||
      metadata.sessionId.toLowerCase() !== id) {
    throw new Error("Invalid C++ language-server session identity.");
  }

  const parentStartTime = execFileSync(path.join(process.env.SystemRoot, "System32", "WindowsPowerShell", "v1.0", "powershell.exe"), [
    "-NoProfile", "-NonInteractive", "-Command",
    `(Get-Process -Id ${process.ppid}).StartTime.ToUniversalTime().Ticks`,
  ], { encoding: "utf8", windowsHide: true, timeout: 10000 }).trim();
  const invocationId = `${process.ppid}-${parentStartTime}`;
  const directory = path.join(process.env.LOCALAPPDATA, "Microsoft", "CppLanguageServer", "SessionDirectories");
  const filename = path.join(directory, `${id}.${invocationId}.json`);
  const temporary = `${filename}.${process.pid}.tmp`;
  fs.mkdirSync(directory, { recursive: true });
  try {
    fs.writeFileSync(temporary, JSON.stringify({
      version: 1, sessionId: id, invocationId, cwd: metadata.workingDirectory,
    }), { flag: "wx", mode: 0o600 });
    fs.renameSync(temporary, filename);
  } finally {
    fs.rmSync(temporary, { force: true });
  }

  const release = () => fs.rmSync(filename, { force: true });
  session.on("session.shutdown", release);
  process.once("exit", release);
  process.once("SIGTERM", () => process.exit(0));
}
