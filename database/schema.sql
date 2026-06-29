
create extension if not exists vector;

create table university_knowledge (
  id        bigserial primary key,
  content   text,
  metadata  jsonb,
  embedding vector(384)
);

create index on university_knowledge
using hnsw (embedding vector_cosine_ops);