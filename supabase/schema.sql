-- Rach Coiffure - schema Supabase (multi-appareils, UUID)
-- A coller dans Supabase > SQL Editor puis Run.
-- Idempotent : peut etre relance sans erreur.

create extension if not exists pgcrypto;

-- Horodatage automatique de updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.app_users (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  telephone text not null unique,
  role text not null default 'gestionnaire',
  actif boolean not null default true,
  permissions text[] not null default '{}',
  auth_uid uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.perruques (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  type text not null,
  longueur text not null,
  couleur text not null,
  texture text not null,
  quantite integer not null default 0,
  prix_achat numeric not null default 0,
  prix_vente numeric not null default 0,
  photo_path text,
  seuil_alerte integer not null default 3,
  fournisseur text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  telephone text not null,
  adresse text,
  points_fidelite integer not null default 0,
  date_creation timestamptz not null default now(),
  date_naissance date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.prestations (
  id uuid primary key default gen_random_uuid(),
  nom text not null,
  prix numeric not null default 0,
  duree_minutes integer not null default 60,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.rendez_vous (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients(id),
  prestation_id uuid references public.prestations(id),
  date_heure timestamptz not null,
  statut text not null default 'prévu',
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.ventes (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references public.clients(id),
  perruque_id uuid references public.perruques(id),
  prestation_id uuid references public.prestations(id),
  montant numeric not null default 0,
  quantite integer not null default 1,
  mode_paiement text not null,
  libelle text,
  remise numeric not null default 0,
  points_utilises integer not null default 0,
  date_vente timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.vente_items (
  id uuid primary key default gen_random_uuid(),
  vente_id uuid not null references public.ventes(id) on delete cascade,
  perruque_id uuid references public.perruques(id),
  libelle text,
  prix_unitaire numeric not null default 0,
  quantite integer not null default 1,
  montant numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.mouvements_stock (
  id uuid primary key default gen_random_uuid(),
  perruque_id uuid not null references public.perruques(id),
  delta integer not null,
  type text not null,
  motif text,
  date timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.depenses (
  id uuid primary key default gen_random_uuid(),
  libelle text not null,
  categorie text,
  montant numeric not null default 0,
  date timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.activites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.app_users(id) on delete set null,
  utilisateur text,
  action text not null,
  details text,
  date timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.parametres (
  cle text primary key,
  valeur text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Index
-- ---------------------------------------------------------------------------

create index if not exists idx_vente_items_vente on public.vente_items(vente_id);
create index if not exists idx_ventes_date on public.ventes(date_vente);
create index if not exists idx_rdv_date on public.rendez_vous(date_heure);
create index if not exists idx_activites_date on public.activites(date);
create index if not exists idx_perruques_updated on public.perruques(updated_at);
create index if not exists idx_clients_updated on public.clients(updated_at);
create index if not exists idx_ventes_updated on public.ventes(updated_at);
create index if not exists idx_vente_items_updated on public.vente_items(updated_at);
create index if not exists idx_rdv_updated on public.rendez_vous(updated_at);
create index if not exists idx_depenses_updated on public.depenses(updated_at);
create index if not exists idx_mouvements_updated on public.mouvements_stock(updated_at);
create index if not exists idx_activites_updated on public.activites(updated_at);
create index if not exists idx_users_updated on public.app_users(updated_at);
create index if not exists idx_prestations_updated on public.prestations(updated_at);
create index if not exists idx_parametres_updated on public.parametres(updated_at);

-- ---------------------------------------------------------------------------
-- Triggers updated_at
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'app_users','perruques','clients','prestations','rendez_vous','ventes',
    'vente_items','mouvements_stock','depenses','activites','parametres'
  ] loop
    execute format('drop trigger if exists trg_%1$s_updated on public.%1$s', t);
    execute format(
      'create trigger trg_%1$s_updated before update on public.%1$s
       for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS : tout utilisateur authentifie a acces (roles fines gerees cote app)
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'app_users','perruques','clients','prestations','rendez_vous','ventes',
    'vente_items','mouvements_stock','depenses','activites','parametres'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_authenticated', t);
    execute format(
      'create policy %I on public.%I for all to authenticated using (true) with check (true)',
      t || '_authenticated', t);
  end loop;
end;
$$;
