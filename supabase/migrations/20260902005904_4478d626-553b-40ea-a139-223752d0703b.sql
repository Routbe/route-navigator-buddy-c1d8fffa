create or replace function public.exec_sql(_query text, _params jsonb default '[]'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  query text := _query;
  i int;
  n int;
  result jsonb;
begin
  n := coalesce(jsonb_array_length(_params), 0);
  for i in 1..n loop
    query := replace(query, '$' || i, quote_nullable(_params->>(i-1)));
  end loop;

  execute query into result;
  return result;
end;
$$;

revoke all on function public.exec_sql(text, jsonb) from public;
grant execute on function public.exec_sql(text, jsonb) to service_role;

create or replace function public.exec_query(_query text, _params jsonb default '[]'::jsonb)
returns setof jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  query text := _query;
  i int;
  n int;
begin
  n := coalesce(jsonb_array_length(_params), 0);
  for i in 1..n loop
    query := replace(query, '$' || i, quote_nullable(_params->>(i-1)));
  end loop;

  return query execute query;
end;
$$;

revoke all on function public.exec_query(text, jsonb) from public;
grant execute on function public.exec_query(text, jsonb) to service_role;