import type { Database } from "../webhook/fixtures.ts";
import type { Admin } from "../../functions/_shared/checkout.ts";

const identifier = (name: string) => {
  if (!/^[a-z_]+$/.test(name)) throw new Error("Invalid test SQL identifier");
  return `"${name}"`;
};
export function adapter(db: Database) {
  const failures = new Set<string>();
  const client = {
    async rpc(name: string, args: Record<string, unknown>) {
      if (failures.delete(name)) {
        return { data: null, error: { message: "Injected failure" } };
      }
      const values = Object.values(args).map((v) =>
        v && typeof v === "object" ? db.json(v as never) : v
      );
      const params = Object.keys(args).map((k, i) =>
        `${identifier(k)}=>$${i + 1}`
      ).join(",");
      try {
        const [row] = await db.unsafe(
          `select public.${identifier(name)}(${params}) result`,
          values as never[],
        );
        return { data: row.result, error: null };
      } catch (error) {
        return { data: null, error };
      }
    },
    from(table: string) {
      return new Query(db, table);
    },
  };
  return { client: client as unknown as Admin, failures };
}

class Query {
  filters: [string, unknown][] = [];
  columns = "*";
  values?: Record<string, unknown>;
  operation = "select";
  constructor(readonly db: Database, readonly table: string) {}
  select(columns: string) {
    this.columns = columns;
    return this;
  }
  eq(key: string, value: unknown) {
    this.filters.push([key, value]);
    return this;
  }
  in(key: string, value: unknown[]) {
    return this.eq(key, value);
  }
  update(values: Record<string, unknown>) {
    this.values = values;
    this.operation = "update";
    return this;
  }
  upsert(values: Record<string, unknown>) {
    this.values = values;
    this.operation = "upsert";
    return this;
  }
  async maybeSingle() {
    const result = await this.execute();
    if (result.error) return result;
    if (result.data.length > 1) {
      return { data: null, error: new Error("Multiple rows") };
    }
    return { data: result.data[0] ?? null, error: null };
  }
  then(resolve: (v: unknown) => unknown, reject: (v: unknown) => unknown) {
    return this.execute().then(resolve, reject);
  }
  async execute() {
    try {
      const args: unknown[] = [];
      const parameter = (v: unknown) => {
        args.push(v);
        return `$${args.length}`;
      };
      const table = `public.${identifier(this.table)}`;
      let sql: string;
      if (this.operation === "upsert") {
        const entries = Object.entries(this.values!);
        sql = `insert into ${table} (${
          entries.map(([k]) => identifier(k)).join(",")
        }) values
          (${
          entries.map(([, v]) => parameter(v)).join(",")
        }) on conflict do nothing`;
      } else {
        sql = this.operation === "update"
          ? `update ${table} set ${
            Object.entries(this.values!).map(([k, v]) =>
              `${identifier(k)}=${parameter(v)}`
            ).join(",")
          }`
          : `select ${
            this.columns === "*"
              ? "*"
              : this.columns.split(",").map(identifier).join(",")
          } from ${table}`;
        const filters = this.filters.map(([k, v]) =>
          Array.isArray(v)
            ? `${identifier(k)} in (${v.map(parameter).join(",")})`
            : `${identifier(k)}=${parameter(v)}`
        );
        if (filters.length) sql += ` where ${filters.join(" and ")}`;
      }
      return { data: await this.db.unsafe(sql, args as never[]), error: null };
    } catch (error) {
      return { data: [] as unknown[], error };
    }
  }
}
