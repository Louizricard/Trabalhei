-- Desfaz 20261027120100_coupons. As Edge Functions de cobrança chamam
-- redeem_coupon: volte-as antes para a versão sem cupons.
drop function if exists public.grant_pro(uuid, integer, text);
drop function if exists public.admin_set_coupon_active(text, boolean);
drop function if exists public.admin_create_coupon(text, text, integer, numeric, integer, timestamptz, text, integer);
drop function if exists public.admin_list_coupons();
drop function if exists public.release_coupon(text);
drop function if exists public.redeem_coupon(uuid, text, text, text);
drop function if exists public.quote_price(text, text);
drop function if exists public.coupon_price(uuid, text, text);
drop table if exists public.coupon_redemptions;
drop table if exists public.coupons;
