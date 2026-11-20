-- Preferência por categoria: a pessoa silencia o e-mail e o push de uma
-- categoria inteira (mensagens, propostas, contratos, atualizações, novas
-- oportunidades). O sino do app continua recebendo tudo. Sem linha ou com a
-- lista vazia, nada fica silenciado.
-- RLS: a política existente notification_settings_own (cada um lê e grava só
-- a própria linha) já cobre a coluna nova.
alter table public.notification_settings
  add column muted_categories text[] not null default '{}'
  constraint notification_settings_muted_categories_valid check (
    muted_categories <@ array['messages', 'proposals', 'contracts', 'updates', 'opportunities']::text[]
  );
