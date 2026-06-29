import { WebSocket } from "ws";
import * as fs from "fs/promises";
import * as path from "path";
import * as os from "os";

export class EditorConnection {
  private ws: WebSocket | null = null;
  private pending = new Map<string, { resolve: (value: unknown) => void; reject: (err: Error) => void; timeout: NodeJS.Timeout }>();
  private nextId = 1;
  private pingInterval: NodeJS.Timeout | null = null;
  private reconnectAttempts = 0;
  private maxReconnects = 3;
  private authToken: string = "";
  private intentionalClose = false;

  constructor(private port = 6550) {}

  async connect(): Promise<void> {
    const tokenDir = process.platform === "win32"
      ? path.join(os.homedir(), "AppData", "Roaming", "Godot", "app_userdata", "ai_godot_mcp")
      : path.join(os.homedir(), ".local", "share", "godot", "app_userdata", "ai_godot_mcp");
    const tokenPath = path.join(tokenDir, "ai_mcp_token");

    try {
      this.authToken = (await fs.readFile(tokenPath, "utf-8")).trim();
    } catch (err) {
      throw new Error(`Failed to read auth token from ${tokenPath}. Ensure Godot editor with AI-godot-mcp plugin is running.`);
    }

    return this._connect();
  }

  private async _connect(): Promise<void> {
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
