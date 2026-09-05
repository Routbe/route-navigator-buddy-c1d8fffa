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
  rec record;
begin
  n := coalesce(jsonb_array_length(_params), 0);
  for i in 1..n loop
    query := replace(query, '$' || i, quote_nullable(_params->>(i-1)));
  end loop;

  for rec in execute query loop
    return next to_jsonb(rec);
  end loop;
end;
$$;

revoke all on function public.exec_query(text, jsonb) from public;
grant execute on function public.exec_query(text, jsonb) to service_role;

create or replace function public.exec_transaction(_queries jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  q jsonb;
  query text;
  params jsonb;
  i int;
  j int;
  n int;
  m int;
  rec record;
  result jsonb;
  results jsonb := '[]'::jsonb;
  rows jsonb;
begin
  results := '[]'::jsonb;
  n := coalesce(jsonb_array_length(_queries), 0);

  for i in 0..n-1 loop
    q := _queries->i;
    query := q->>'query';
    params := coalesce(q->'params', '[]'::jsonb);
    m := coalesce(jsonb_array_length(params), 0);
    for j in 1..m loop
      query := replace(query, '$' || j, quote_nullable(params->>(j-1)));
    end loop;

    rows := '[]'::jsonb;
    for rec in execute query loop
      rows := rows || to_jsonb(rec);
    end loop;
    results := results || jsonb_build_array(rows);
  end loop;

  return results;
end;
$$;

revoke all on function public.exec_transaction(jsonb) from public;
grant execute on function public.exec_transaction(jsonb) to service_role;