create or replace function match_university_knowledge (
  query_embedding vector(384),
  match_count     int default 5
)
returns table (
  id         bigint,
  content    text,
  metadata   jsonb,
  similarity float
)
language sql stable
as $$
  select
    id,
    content,
    metadata,
    1 - (embedding <=> query_embedding) as similarity
  from university_knowledge
  order by embedding <=> query_embedding
  limit match_count;
$$;
