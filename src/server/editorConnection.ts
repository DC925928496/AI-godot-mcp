import { WebSocket } from "ws";
import * as fs from "fs/promises";
import * as path from "path";
import * as os from "os";

const AUTH_TOKEN_FILE = "ai_mcp_token";
const LEGACY_TOKEN_DIR = "ai_godot_mcp";

type AuthTokenCandidate = {
  token: string;
  tokenPath: string;
  priority: number;
  mtimeMs: number;
};

function getDefaultGodotUserDataRoot(): string {
  return process.platform === "win32"
    ? path.join(os.homedir(), "AppData", "Roaming", "Godot", "app_userdata")
    : path.join(os.homedir(), ".local", "share", "godot", "app_userdata");
}

export class EditorConnection {
  private ws: WebSocket | null = null;
  private pending = new Map<string, { resolve: (value: unknown) => void; reject: (err: Error) => void; timeout: NodeJS.Timeout }>();
  private nextId = 1;
  private pingInterval: NodeJS.Timeout | null = null;
  private reconnectAttempts = 0;
  private maxReconnects = 3;
  private authToken: string = "";
  private intentionalClose = false;

  constructor(private port = 6550, private godotUserDataRoot = getDefaultGodotUserDataRoot()) {}

  async connect(): Promise<void> {
    const candidates = await this._getAuthTokenCandidates();
    if (candidates.length === 0) {
      throw new Error(
        `No AI-godot-mcp auth token files found under ${this.godotUserDataRoot}. ` +
        "Ensure the Godot editor is running and the AI-godot-mcp plugin is enabled.",
      );
    }

    const failures: string[] = [];
    for (const candidate of candidates) {
      try {
        await this._connect(candidate.token);
        return;
      } catch (err) {
        this._discardFailedSocket();
        failures.push(`${candidate.tokenPath}: ${err instanceof Error ? err.message : String(err)}`);
      }
    }

    throw new Error(
      `Failed to authenticate with the Godot editor using ${candidates.length} token file(s). ` +
      "Ensure only one Godot editor is listening on port " + this.port + " and the AI-godot-mcp plugin was restarted. " +
      `Attempts: ${failures.join("; ")}`,
    );
  }

  private async _getAuthTokenCandidates(): Promise<AuthTokenCandidate[]> {
    const byPath = new Map<string, AuthTokenCandidate>();
    const addCandidate = async (tokenPath: string, priority: number) => {
      try {
        const [stat, token] = await Promise.all([
          fs.stat(tokenPath),
          fs.readFile(tokenPath, "utf-8"),
        ]);
        const trimmedToken = token.trim();
        if (trimmedToken.length > 0) {
          byPath.set(tokenPath, { token: trimmedToken, tokenPath, priority, mtimeMs: stat.mtimeMs });
        }
      } catch {
        // Missing or unreadable token candidates are skipped; connect() reports if none work.
      }
    };

    await addCandidate(path.join(this.godotUserDataRoot, LEGACY_TOKEN_DIR, AUTH_TOKEN_FILE), 0);

    try {
      const entries = await fs.readdir(this.godotUserDataRoot, { withFileTypes: true });
      await Promise.all(entries
        .filter(entry => entry.isDirectory())
        .map(entry => addCandidate(path.join(this.godotUserDataRoot, entry.name, AUTH_TOKEN_FILE), 1)));
    } catch {
      // The legacy path attempt above already covered the direct compatibility location.
    }

    return [...byPath.values()].sort((left, right) =>
      left.priority - right.priority || right.mtimeMs - left.mtimeMs || left.tokenPath.localeCompare(right.tokenPath),
    );
  }

  private async _connect(authToken: string = this.authToken): Promise<void> {
    this.intentionalClose = false;
    this.ws = new WebSocket(`ws://localhost:${this.port}`);

    this.ws.on("message", (data) => {
      const res = JSON.parse(data.toString());
      const cb = this.pending.get(res.id);
      if (!cb) return;

      clearTimeout(cb.timeout);
      this.pending.delete(res.id);

      if (res.ok) {
        cb.resolve(res.data);
      } else {
        const errorMsg = res.error?.message || "Unknown error";
        const errorCode = res.error?.code || "UNKNOWN_ERROR";
        cb.reject(new Error(`${errorCode}: ${errorMsg}`));
      }
    });

    this.ws.on("close", () => {
      const shouldReconnect = !this.intentionalClose && this.reconnectAttempts < this.maxReconnects;
      this._cleanup(shouldReconnect);
      if (shouldReconnect) {
        this.reconnectAttempts++;
        const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts - 1), 8000);
        setTimeout(() => this._connect().catch(() => {}), delay);
      }
    });

    await new Promise((ok, fail) => {
      this.ws!.once("open", ok);
      this.ws!.once("error", fail);
    });

    this.authToken = authToken;
    await this.send("get_project_context");
    this.reconnectAttempts = 0;
    this._startPing();
  }

  close(): void {
    this.intentionalClose = true;
    this.reconnectAttempts = this.maxReconnects;
    this._cleanup(false);
    this.ws?.close();
    this.ws = null;
  }

  private _startPing(): void {
    this.pingInterval = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.ping();
      }
    }, 10000);
  }

  private _cleanup(isReconnecting = false): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
    for (const [id, cb] of this.pending) {
      clearTimeout(cb.timeout);
      cb.reject(new Error(isReconnecting ? "Connection lost, reconnecting..." : "Connection closed"));
    }
    this.pending.clear();
  }

  private _discardFailedSocket(): void {
    const socket = this.ws;
    this.intentionalClose = true;
    this._cleanup(false);
    if (socket) {
      socket.removeAllListeners();
      socket.close();
    }
    this.ws = null;
  }

  async send(method: string, params?: unknown, txnId?: string | null): Promise<unknown> {
    const deadline = Date.now() + 5000;
    while ((!this.ws || this.ws.readyState !== WebSocket.OPEN) && Date.now() < deadline) {
      await new Promise(r => setTimeout(r, 100));
    }

    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
      throw new Error("WebSocket not connected");
    }

    const id = (this.nextId++).toString();
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Request timeout: ${method}`));
      }, 10000);

      this.pending.set(id, { resolve, reject, timeout });
      this.ws!.send(JSON.stringify({ id, method, params, txn_id: txnId, auth_token: this.authToken }));
    });
  }
}
