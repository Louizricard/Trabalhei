import { checkoutHandler } from "../_shared/checkout.ts";
import { featureCheckout } from "../_shared/checkout_products.ts";

Deno.serve(checkoutHandler("job_feature", featureCheckout));
