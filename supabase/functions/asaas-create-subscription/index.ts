import { checkoutHandler } from "../_shared/checkout.ts";
import { proCheckout } from "../_shared/checkout_products.ts";

Deno.serve(checkoutHandler("pro_monthly", proCheckout));
