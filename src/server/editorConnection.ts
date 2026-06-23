import { WebSocket } from "ws";

export class EditorConnection {
  private ws: WebSocket | null = null;
  private pending = new Map<string, (value: unknown) => void>();

  constructor(private port = 6550) {}

  async connect(): Promise<void> {
    this.ws = new WebSocket(`ws://localhost:${this.port}`);
    this.ws.on("message", (data) => {
      const res = JSON.parse(data.toString());
      this.pending.get(res.id)?.(res.ok ? res.data : Promise.reject(new Error(res.error?.message)));
      this.pending.delete(res.id);
    });
    await new Promise((ok, fail) => {
      this.ws!.once("open", ok);
      this.ws!.once("error", fail);
    });
  }

  async send(method: string, params?: unknown): Promise<unknown> {
    const id = Date.now().toString();
    return new Promise((resolve) => {
      this.pending.set(id, resolve);
      this.ws!.send(JSON.stringify({ id, method, params }));
    });
  }
}
