import type { Body } from "../../functions/_shared/checkout.ts";

export class Provider {
  records: Record<string, Body[]> = {
    "/customers": [],
    "/subscriptions": [],
    "/payments": [],
  };
  posts: Record<string, number> = {};
  loseResponse?: string;
  beforeReturn?: (path: string, value: Body) => Promise<void>;
  readonly fetch: typeof fetch = async (input, options) => {
    const url = new URL(String(input));
    const path = url.pathname.replace("/v3", "");
    const method = options?.method ?? "GET";
    const body = options?.body ? JSON.parse(String(options.body)) : {};
    let result: unknown;
    if (method === "POST") {
      this.posts[path] = (this.posts[path] ?? 0) + 1;
      const record = { ...body, id: `${path.slice(1)}_${crypto.randomUUID()}` };
      this.records[path].push(record);
      if (path === "/subscriptions") {
        this.payment({ ...body, subscription: record.id });
      }
      if (path === "/payments") {
        Object.assign(record, this.payment(body, false), { id: record.id });
      }
      await this.beforeReturn?.(path, record);
      if (this.loseResponse === path) {
        this.loseResponse = undefined;
        throw new TypeError("Simulated lost response after creation");
      }
      result = record;
    } else if (path.endsWith("/pixQrCode")) {
      result = { encodedImage: "fake-png", payload: "fake-pix" };
    } else if (/^\/subscriptions\/[^/]+\/payments$/.test(path)) {
      result = {
        data: this.records["/payments"].filter((p) =>
          p.subscription === path.split("/")[2]
        ),
      };
    } else if (this.records[path]) {
      result = {
        data: this.records[path].filter((p) =>
          p.externalReference === url.searchParams.get("externalReference")
        ),
      };
    } else {
      const collection = "/" + path.split("/")[1];
      const record = this.records[collection].find((p) =>
        p.id === path.split("/")[2]
      );
      if (!record) throw new Error(`Missing fake remote ${path}`);
      if (method === "PUT") {
        Object.assign(record, body);
        if (collection === "/subscriptions" && body.updatePendingPayments) {
          this.records["/payments"].filter((p) => p.subscription === record.id)
            .forEach((p) => p.billingType = body.billingType);
        }
      }
      result = record;
    }
    return new Response(JSON.stringify(result), {
      headers: { "content-type": "application/json" },
    });
  };
  payment(body: Body, save = true) {
    const p = {
      ...body,
      id: `pay_${crypto.randomUUID()}`,
      status: "PENDING",
      invoiceUrl: "https://example.invalid/invoice",
      dueDate: "2026-10-29",
    };
    if (save) this.records["/payments"].push(p);
    return p;
  }
}
