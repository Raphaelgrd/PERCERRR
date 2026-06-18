-- ============================================================
--  Percerr — configuration Supabase (nouvelle version)
--  À exécuter UNE fois : Supabase → SQL Editor → New query → coller → Run.
--
--  Cette version utilise l'authentification Supabase (comptes e-mail /
--  mot de passe) + 2 tables protégées par Row Level Security :
--    • workspace  → le tableau partagé (un seul document JSON)
--    • messages   → le chat d'équipe
--  Le navigateur n'utilise que la clé "anon" (publique) ; la RLS garantit
--  que seuls les utilisateurs connectés peuvent lire/écrire.
-- ============================================================

-- ---------- 1) tableau partagé ----------
create table if not exists public.workspace (
  id text primary key default 'singleton',
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.workspace enable row level security;

drop policy if exists "workspace authenticated" on public.workspace;
create policy "workspace authenticated"
  on public.workspace for all
  to authenticated
  using (true) with check (true);

-- ---------- 2) chat d'équipe ----------
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  user_id uuid not null,
  name text,
  color text,
  created_at timestamptz not null default now()
);

alter table public.messages enable row level security;

drop policy if exists "messages read" on public.messages;
create policy "messages read"
  on public.messages for select
  to authenticated using (true);

drop policy if exists "messages insert own" on public.messages;
create policy "messages insert own"
  on public.messages for insert
  to authenticated with check (auth.uid() = user_id);

-- ---------- 3) temps réel (synchro live du tableau + du chat) ----------
alter publication supabase_realtime add table public.workspace;
alter publication supabase_realtime add table public.messages;

-- ---------- 4) stockage des pièces jointes des cartes ----------
-- Bucket public « attachments » : lecture par lien public, écriture/suppression
-- réservées aux utilisateurs connectés. (Réexécute ce bloc si tu mets à jour.)
insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', true)
on conflict (id) do nothing;

drop policy if exists "attachments read"   on storage.objects;
create policy "attachments read"   on storage.objects for select
  to public using (bucket_id = 'attachments');

drop policy if exists "attachments insert" on storage.objects;
create policy "attachments insert" on storage.objects for insert
  to authenticated with check (bucket_id = 'attachments');

drop policy if exists "attachments delete" on storage.objects;
create policy "attachments delete" on storage.objects for delete
  to authenticated using (bucket_id = 'attachments');
