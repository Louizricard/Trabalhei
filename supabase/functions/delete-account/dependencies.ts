import {
  adminClient,
  asaas,
  AsaasError,
  env,
  HttpError,
  json,
  reportError,
  requireUser,
} from "../_shared/common.ts";
import {
  type DeletionDependencies,
  DeletionError,
  type DeletionRequest,
  type StoredObject,
} from "./workflow.ts";

async function isOperator(req: Request) {
  const token = req.headers.get("authorization")?.replace(/^Bearer /i, "") ??
    "";
  const digest = (value: string) =>
    crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  const [a, b] = await Promise.all([
    digest(token),
    digest(env("SUPABASE_SERVICE_ROLE_KEY")),
  ]);
  const left = new Uint8Array(a), right = new Uint8Array(b);
  let diff = 0;
  for (let i = 0; i < left.length; i++) diff |= left[i] ^ right[i];
  return diff === 0;
}

type Admin = ReturnType<typeof adminClient>;
async function rpc<T>(
  admin: Admin,
  name: string,
  args: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await admin.rpc(name, args);
  if (error) {
    if (error.message.includes("DELETION_BILLING_PENDING")) {
      throw new DeletionError(
        409,
        "Retome o pagamento pendente antes de excluir a conta ou fale com o suporte.",
      );
    }
    if (error.message.includes("ACTIVE_CONTRACTS")) {
      throw new DeletionError(
        409,
        "Conclua os contratos em andamento antes de excluir a conta.",
      );
    }
    if (/DELETION_BUSY|DELETION_LEASE_LOST/.test(error.message)) {
      throw new DeletionError(
        409,
        "Uma exclusão já está em andamento. Aguarde e tente novamente.",
      );
    }
    throw new Error("DELETION_DATABASE_ERROR");
  }
  return data as T;
}
async function authorize(req: Request) {
  if (await isOperator(req)) {
    const body = await req.json().catch(() => ({}));
    if (
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
        .test(String(body.user_id))
    ) {
      throw new DeletionError(400, "Identificador inválido.");
    }
    return body.user_id;
  }
  try {
    return (await requireUser(req, true)).id;
  } catch (error) {
    if (error instanceof HttpError) {
      throw new DeletionError(error.status, error.message);
    }
    throw error;
  }
}

async function cancelBilling(admin: Admin, user: string) {
  const { data: sub, error } = await admin.from("subscriptions").select(
    "id,asaas_subscription_id",
  )
    .eq("user_id", user).in("status", ["pending", "active", "overdue"])
    .maybeSingle();
  if (error) throw new Error("BILLING_READ_ERROR");
  if (!sub) return;
  try {
    await asaas(`/subscriptions/${sub.asaas_subscription_id}`, {
      method: "DELETE",
    });
  } catch (error) {
    if (!(error instanceof AsaasError && error.providerStatus === 404)) {
      throw error;
    }
  }
  const result = await admin.from("subscriptions").update({
    status: "cancelled",
  }).eq("id", sub.id);
  if (result.error) throw new Error("BILLING_WRITE_ERROR");
}

function storageAndAuth(admin: Admin) {
  return {
    objects: (user, token) =>
      rpc<StoredObject[]>(admin, "account_deletion_objects", {
        p_user: user,
        p_token: token,
      }),
    async remove(bucket, names) {
      const { error } = await admin.storage.from(bucket).remove(names);
      if (error) throw new Error("STORAGE_REMOVE_ERROR");
    },
    prepareAuth: (user, token) =>
      rpc<void>(admin, "prepare_account_auth_deletion", {
        p_user: user,
        p_token: token,
      }),
    async eraseAuth(user, soft) {
      const { error } = await admin.auth.admin.deleteUser(user, soft);
      if (error && error.status !== 404) throw new Error("AUTH_DELETE_ERROR");
    },
  } satisfies Pick<
    DeletionDependencies,
    "objects" | "remove" | "prepareAuth" | "eraseAuth"
  >;
}

export function deletionDependencies(): DeletionDependencies {
  const admin = adminClient();
  return {
    authorize,
    begin: (user) =>
      rpc<DeletionRequest>(admin, "begin_account_deletion", { p_user: user }),
    cancelBilling: (user) => cancelBilling(admin, user),
    ...storageAndAuth(admin),
    complete: (user, token) =>
      rpc<void>(admin, "complete_account_deletion", {
        p_user: user,
        p_token: token,
      }),
    fail: (user, token, step) =>
      rpc<void>(admin, "fail_account_deletion", {
        p_user: user,
        p_token: token,
        p_code: step,
      }),
    report: (step) =>
      reportError(
        "delete-account",
        new Error(`Account deletion failed: ${step}`),
      ),
    reply: json,
  };
}
