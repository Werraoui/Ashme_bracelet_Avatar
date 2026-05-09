-- Run in Supabase SQL Editor: remove Telegram-related columns from contacts.
-- If a column does not exist yet, the statement is skipped (PostgreSQL IF EXISTS).

alter table public.contacts drop column if exists telegram_chat_id;
alter table public.contacts drop column if exists telegram_link_token;
alter table public.contacts drop column if exists telegram_linked_at;
