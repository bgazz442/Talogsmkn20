-- Remove the retired ecosystem and live monitoring data surfaces.

drop table if exists public.user_presence cascade;
drop table if exists public.activity_feed cascade;
drop table if exists public.department_health cascade;
drop table if exists public.dashboard_metrics cascade;