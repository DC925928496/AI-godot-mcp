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

  constructor(private port = 6550) {}

  async connect(): Promise<void> {
    try {
      const tokenDir = process.platform === "win32"
        ? path.join(os.homedir(), "AppData", "Roaming", "Godot", "app_userdata", "ai_godot_mcp")
        : path.join(os.homedir(), ".local", "share", "godot", "app_userdata", "ai_godot_mcp");
      const tokenPath = path.join(tokenDir, "ai_mcp_token");
      this.authToken = (await fs.readFile(tokenPath, "utf-8")).trim();
    } catch {
      this.authToken = "";
    }

    return this._connect();
  }

  private async _connect(): Promise<void> {
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
      this._cleanup();
      if (this.reconnectAttempts < this.maxReconnects) {
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

  private _startPing(): void {
    this.pingInterval = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.ping();
      }
    }, 10000);
  }

  private _cleanup(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
    for (const [id, cb] of this.pending) {
      clearTimeout(cb.timeout);
      cb.reject(new Error("Connection closed"));
    }
    this.pending.clear();
  }

  async send(method: string, params?: unknown, txnId?: string | null): Promise<unknown> {
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
