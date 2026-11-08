-- Terminal Prop · base de datos en el Supabase de Juan (proyecto Terminl-prop).
-- Se pega entero en Supabase → SQL Editor → Run. Se ejecuta UNA vez.
-- Qué crea: tope de cuentas y código de invitación (comprobados al registrarse),
-- un documento por usuario con acceso solo a lo suyo, y un historial de versiones.

-- Ajustes internos (código de invitación y tope). Con RLS y sin políticas: la web no puede leerla.
create table public.ajustes (
  clave text primary key,
  valor text not null
);
alter table public.ajustes enable row level security;

insert into public.ajustes (clave, valor) values
  ('codigo_invitacion', upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8))),
  ('max_cuentas', '15');

-- Antes de crear un usuario: código de invitación correcto y tope de cuentas.
create or replace function public.comprobar_registro()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cod text;
  mx int;
  n int;
begin
  perform pg_advisory_xact_lock(15);
  select valor into cod from public.ajustes where clave = 'codigo_invitacion';
  select valor::int into mx from public.ajustes where clave = 'max_cuentas';
  if cod is null
     or lower(trim(coalesce(new.raw_user_meta_data->>'codigo', ''))) <> lower(trim(cod)) then
    raise exception 'Código de invitación no válido';
  end if;
  select count(*) into n from auth.users;
  if n >= mx then
    raise exception 'Se ha alcanzado el máximo de cuentas';
  end if;
  return new;
end;
$$;
revoke all on function public.comprobar_registro() from public, anon, authenticated;

create trigger antes_de_crear_usuario
  before insert on auth.users
  for each row execute function public.comprobar_registro();

-- Un documento por usuario (todo su registro), con revisión para juntar cambios entre aparatos.
create table public.registros (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  rev integer not null default 1,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  constraint registros_tamano check (pg_column_size(data) < 2000000)
);
alter table public.registros enable row level security;

create policy "ver lo mío" on public.registros
  for select to authenticated using (user_id = (select auth.uid()));
create policy "crear lo mío" on public.registros
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "cambiar lo mío" on public.registros
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Historial: las 100 últimas versiones de cada usuario, para recuperar si borra sin querer.
create table public.historial (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  rev integer not null,
  data jsonb not null,
  created_at timestamptz not null default now()
);
create index historial_usuario_idx on public.historial (user_id, id desc);
alter table public.historial enable row level security;
create policy "ver mi historial" on public.historial
  for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.guardar_historial()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.historial (user_id, rev, data) values (new.user_id, new.rev, new.data);
  delete from public.historial
   where user_id = new.user_id
     and id not in (select id from public.historial where user_id = new.user_id order by id desc limit 100);
  return new;
end;
$$;
revoke all on function public.guardar_historial() from public, anon, authenticated;

create trigger registros_historial
  after insert or update on public.registros
  for each row execute function public.guardar_historial();

-- Latido: la tarea diaria de GitHub lo llama para que el proyecto gratis no se pause por inactividad.
create or replace function public.latido()
returns timestamptz
language sql
security definer
set search_path = ''
as $$ select now(); $$;
grant execute on function public.latido() to anon, authenticated;

-- Para ver o cambiar el código de invitación (lo reparte Juan):
--   select valor from public.ajustes where clave = 'codigo_invitacion';
--   update public.ajustes set valor = 'NUEVOCODIGO' where clave = 'codigo_invitacion';
