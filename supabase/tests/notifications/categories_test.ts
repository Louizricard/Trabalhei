import assert from "node:assert/strict";
import { categoryOf, isMuted } from "../../functions/dispatch-notification/categories.ts";

Deno.test("cada tipo cai na categoria certa", () => {
  assert.equal(categoryOf("new_message"), "messages");
  assert.equal(categoryOf("proposal_received"), "proposals");
  assert.equal(categoryOf("proposal_accepted"), "proposals");
  assert.equal(categoryOf("contract_completed"), "contracts");
  assert.equal(categoryOf("milestone_submitted"), "contracts");
  assert.equal(categoryOf("milestone_approved"), "contracts");
  assert.equal(categoryOf("job_alert"), "opportunities");
  assert.equal(categoryOf("system"), "updates");
  assert.equal(categoryOf("job_removed"), "updates");
  assert.equal(categoryOf("tipo_novo_desconhecido"), "updates");
});

Deno.test("categoria silenciada não envia e-mail nem push", () => {
  assert.equal(isMuted("new_message", ["messages"]), true);
  assert.equal(isMuted("job_alert", ["opportunities"]), true);
  assert.equal(isMuted("proposal_received", ["messages"]), false);
  assert.equal(isMuted("system", []), false);
  assert.equal(isMuted("system", null), false);
});

Deno.test("aviso da moderação chega mesmo com Atualizações silenciadas", () => {
  assert.equal(isMuted("account_suspended", ["updates"]), false);
  assert.equal(isMuted("account_restored", ["updates"]), false);
});
