create extension if not exists pgcrypto;

create table if not exists public.five_s_departments (
  department_id uuid primary key default gen_random_uuid(),
  department_name text not null unique,
  default_area_type text,
  line_required boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.five_s_categories (
  code text primary key,
  name text not null unique,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.five_s_criteria (
  criterion_id uuid primary key default gen_random_uuid(),
  department_id uuid not null references public.five_s_departments(department_id) on delete cascade,
  category_code text not null references public.five_s_categories(code),
  title text not null,
  description text,
  max_score integer not null default 5 check (max_score > 0),
  weight numeric(10,2) not null default 1,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists idx_five_s_criteria_department_title
  on public.five_s_criteria (department_id, title);

create index if not exists idx_five_s_criteria_department_category
  on public.five_s_criteria (department_id, category_code, sort_order);

insert into public.five_s_categories (code, name, sort_order)
values
  ('SORT', 'Sort', 1),
  ('SET_IN_ORDER', 'Set in Order', 2),
  ('SHINE', 'Shine', 3),
  ('STANDARDIZE', 'Standardize', 4),
  ('SUSTAIN', 'Sustain', 5)
on conflict (code) do update
set name = excluded.name,
    sort_order = excluded.sort_order;

insert into public.five_s_departments (department_name, default_area_type, line_required, sort_order)
values
  ('Sewing', 'Line', true, 1),
  ('Cutting', 'Area', false, 2),
  ('Finishing', 'Area', false, 3),
  ('Store', 'Area', false, 4)
on conflict (department_name) do update
set default_area_type = excluded.default_area_type,
    line_required = excluded.line_required,
    sort_order = excluded.sort_order;

insert into public.five_s_criteria (department_id, category_code, title, description, max_score, weight, sort_order)
select d.department_id, x.category_code, x.title, x.description, x.max_score, x.weight, x.sort_order
from public.five_s_departments d
join (
  values
    ('Sewing', 'SORT', 'Unnecessary items removed from line', 'Only required tools and trims are present on the line.', 5, 1.00, 1),
    ('Sewing', 'SET_IN_ORDER', 'Line tools arranged and labeled', 'Bins, attachments, guides and accessories are organized.', 5, 1.00, 2),
    ('Sewing', 'SHINE', 'Machine and workstation cleanliness', 'Tables, floors and machines are clean.', 5, 1.00, 3),
    ('Cutting', 'SORT', 'Fabric rolls and tools are segregated', 'Non-required materials are removed from the cutting area.', 5, 1.00, 1),
    ('Cutting', 'SHINE', 'Cutting table and floor cleanliness', 'Dust and scraps are cleared and safe to work.', 5, 1.00, 2),
    ('Finishing', 'STANDARDIZE', 'Finishing standards displayed', 'Approved guides and references are visible and current.', 5, 1.00, 1),
    ('Store', 'SUSTAIN', 'Aisles and racks follow standard discipline', 'Storage lanes remain marked, usable and compliant.', 5, 1.00, 1)
) as x(department_name, category_code, title, description, max_score, weight, sort_order)
  on d.department_name = x.department_name
on conflict (department_id, title) do update
set category_code = excluded.category_code,
    description = excluded.description,
    max_score = excluded.max_score,
    weight = excluded.weight,
    sort_order = excluded.sort_order,
    is_active = true,
    updated_at = now();

comment on table public.five_s_departments is 'Master departments used to scope 5S criteria and audits.';
comment on table public.five_s_criteria is 'Department-wise 5S criteria downloaded to devices for offline audits.';
comment on column public.five_s_criteria.max_score is 'App renders a dropdown from 0..max_score for this criterion.';
comment on column public.five_s_criteria.weight is 'Optional weighting factor for future reporting and scoring logic.';

-- Suggested local server database tables for FastAPI
-- five_s_audit_headers:
--   audit_id pk, department_id, department_name, area_line, audit_date,
--   auditor_id, auditor_name, production_representative,
--   signature_base64 or signature_file_path,
--   total_score, max_score, percentage, rating_band,
--   remarks, created_at, uploaded_at
-- five_s_audit_details:
--   id pk, audit_id fk, criterion_id, category_code, criterion_title,
--   max_score, weight, score, issue_flag
-- five_s_audit_photos:
--   id pk, audit_id fk, local_path, photo_file_path or photo_data_base64,
--   captured_at, photo_size_bytes
