-- Run in Supabase SQL Editor: add ack token for contact email acknowledgements.

alter table public.alertes
  add column if not exists ack_token text;

create unique index if not exists uq_alertes_ack_token
  on public.alertes (ack_token)
  where ack_token is not null;

