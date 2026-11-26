-- =====================================================================
--  V TEMPLATES – Volamp HR Letter Studio
--  Supabase (PostgreSQL) database setup
--  HOW TO USE: Supabase → SQL Editor → New query → paste ALL of this → Run
--  Safe to run again (it will not delete your data).
-- =====================================================================

-- 1) SETTINGS: one single row holding company letterhead details + running letter number
create table if not exists settings (
  id          int primary key default 1 check (id = 1),   -- only one row allowed
  data        jsonb not null default '{}'::jsonb,           -- company name, address, logo, prefix, salary %
  next_seq    int  not null default 1,                      -- next letter running number
  updated_at  timestamptz not null default now()
);
insert into settings (id, data)
values (1, '{"company_name":"Volamp Elektrikals Pvt. Ltd.","ref_prefix":"VEPL/HR","basic_pct":50,"hra_pct":40}'::jsonb)
on conflict (id) do nothing;

-- 2) SIGNATORIES: people who sign letters (signature + stamp images)
create table if not exists signatories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null default '',
  designation text not null default '',
  signature   text default '',       -- image stored as text (data URL)
  stamp       text default '',
  created_at  timestamptz not null default now()
);

-- 3) TEMPLATES: letter formats (offer, appointment, warning ...)
create table if not exists templates (
  id          uuid primary key default gen_random_uuid(),
  key         text unique,                  -- for built-in templates (offer, appointment ...)
  name        text not null,
  code        text not null default 'GEN',  -- used in reference number e.g. OFR
  category    text not null default 'Other',
  ack         boolean not null default false,  -- employee acknowledgement section
  approved    boolean not null default false,
  approved_by text default '',
  approved_on date,
  builtin     boolean not null default false,
  body        text not null default '',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- 4) EMPLOYEES: employee master
create table if not exists employees (
  id                uuid primary key default gen_random_uuid(),
  emp_code          text,
  salutation        text,
  employee_name     text not null,
  designation       text,
  department        text,
  location          text,
  date_of_joining   date,
  reporting_manager text,
  monthly_ctc       numeric(12,2),
  mobile            text,
  email             text,
  address           text,
  created_at        timestamptz not null default now()
);

-- 5) LETTERS: register of every letter issued
create table if not exists letters (
  id               uuid primary key default gen_random_uuid(),
  ref_no           text unique not null,
  letter_date      date not null,
  template_id      uuid references templates(id) on delete set null,
  template_name    text,
  employee         text,
  emp_code         text,
  signatory_id     uuid references signatories(id) on delete set null,
  signed_by        text,
  vals             jsonb not null default '{}'::jsonb,   -- all filled details, for reprint
  reprints         int not null default 0,
  issued_by_email  text default (auth.jwt() ->> 'email'),
  issued_at        timestamptz not null default now()
);
create index if not exists letters_issued_at_idx on letters (issued_at desc);

-- 6) SECURITY (Row Level Security): only logged-in staff can read/write anything
alter table settings    enable row level security;
alter table signatories enable row level security;
alter table templates   enable row level security;
alter table employees   enable row level security;
alter table letters     enable row level security;

drop policy if exists "staff full access" on settings;
drop policy if exists "staff full access" on signatories;
drop policy if exists "staff full access" on templates;
drop policy if exists "staff full access" on employees;
drop policy if exists "staff full access" on letters;

create policy "staff full access" on settings    for all to authenticated using (true) with check (true);
create policy "staff full access" on signatories for all to authenticated using (true) with check (true);
create policy "staff full access" on templates   for all to authenticated using (true) with check (true);
create policy "staff full access" on employees   for all to authenticated using (true) with check (true);
create policy "staff full access" on letters     for all to authenticated using (true) with check (true);

-- 7) ISSUE LETTER FUNCTION: gives the next reference number safely
--    (two HR people clicking "Issue" at the same moment never get the same number)
create or replace function issue_letter(
  p_code text, p_letter_date date, p_template_id uuid, p_template_name text,
  p_employee text, p_emp_code text, p_signatory_id uuid, p_signed_by text, p_vals jsonb)
returns letters
language plpgsql
as $$
declare
  v_seq    int;
  v_prefix text;
  v_year   int;
  v_fy     text;
  v_row    letters;
begin
  update settings set next_seq = next_seq + 1, updated_at = now()
   where id = 1
  returning next_seq - 1, coalesce(nullif(data ->> 'ref_prefix', ''), 'HR')
       into v_seq, v_prefix;

  if v_seq is null then
    raise exception 'Not allowed – please log in again';
  end if;

  -- Indian financial year: April to March  →  2026-27
  v_year := extract(year from p_letter_date)::int
            - case when extract(month from p_letter_date) < 4 then 1 else 0 end;
  v_fy   := v_year || '-' || right((v_year + 1)::text, 2);

  insert into letters (ref_no, letter_date, template_id, template_name, employee,
                       emp_code, signatory_id, signed_by, vals)
  values (v_prefix || '/' || coalesce(nullif(p_code, ''), 'GEN') || '/' || v_fy || '/' || lpad(v_seq::text, 3, '0'),
          p_letter_date, p_template_id, p_template_name, p_employee,
          p_emp_code, p_signatory_id, p_signed_by, coalesce(p_vals, '{}'::jsonb))
  returning * into v_row;

  return v_row;
end;
$$;

revoke execute on function issue_letter(text, date, uuid, text, text, text, uuid, text, jsonb) from public, anon;
grant  execute on function issue_letter(text, date, uuid, text, text, text, uuid, text, jsonb) to authenticated;

-- Done ✔  Now go to Authentication → Users → Add user, to create HR logins.
