# Setup Guide

This guide walks you through deploying your own instance
of Ibadat AI Assistant for any institution or knowledge domain.

---

## What you need

- n8n account — cloud at n8n.io or self-hosted
- Supabase account — free tier works fine
- HuggingFace account — free API key
- OpenRouter account — free credits on signup
- Google Drive — to store your knowledge document

---

## 1. Prepare your knowledge document

Write or export your knowledge base as a `.md` file.
Markdown works better than PDF here — headings and
paragraph breaks give the text splitter natural cut points,
so chunks come out cleaner.

Upload it to Google Drive. After uploading, open the file
and copy the share link. Your file ID is the string
between `/d/` and `/view`:

```
https://drive.google.com/file/d/THIS_IS_YOUR_FILE_ID/view
```

Save that ID — you will need it later.

---

## 2. Set up Supabase

Go to supabase.com → create a new project.

Once it is ready, go to **SQL Editor** and run both files
from the `/database` folder in this order:

**First — schema.sql**

This creates the `university_knowledge` table with the
correct column types and an HNSW index on the embedding
column for fast similarity search.

**Second — rpc_function.sql**

This creates the `match_university_knowledge` function
that the retrieval workflow calls. It runs cosine
similarity search via pgvector's `<=>` operator entirely
inside the database.

After running both, go to **Table Editor** and confirm
`university_knowledge` exists with these columns:

```
id          bigserial
content     text
metadata    jsonb
embedding   vector(384)
```

If the table is there you are good.

---

## 3. Get your Supabase credentials

Go to your Supabase project → **Settings → API**

You need two values:
- **Project URL** — looks like `https://xxxx.supabase.co`
- **Service Role Key** — under API keys, use the service
  role key not the anon key

Keep these safe — do not commit them anywhere.

---

## 4. Set up credentials in n8n

Go to n8n → **Settings → Credentials → Add Credential**

Create these four credentials:

**Supabase**
- Type: Supabase
- Host: your Project URL from step 3
- Service Role Key: from step 3

**HuggingFace**
- Type: HuggingFace Token
- Go to huggingface.co → Settings → Access Tokens
- Create a new token with read access
- Paste it in

**OpenRouter**
- Type: OpenRouter
- Go to openrouter.ai → Keys → Create Key
- Paste it in

**Google Drive**
- Type: Google Drive OAuth2
- n8n will walk you through the OAuth flow
- Make sure you connect the Google account that
  has access to your knowledge document

Note down the credential names you give each one —
you will reference them in the workflows.

---

## 5. Import the workflows

In n8n go to **Workflows → + → Import from File**

Import both files from the `/workflows` folder:
- `ingestion_pipeline.json`
- `retrieval_pipeline.json`

---

## 6. Configure the ingestion workflow

Open the ingestion workflow. You need to update three nodes:

**Download file node (Google Drive)**
- Click the node
- Under File ID, replace `YOUR_GOOGLE_DRIVE_FILE_ID`
  with the file ID you copied in step 1
- Under credentials, select your Google Drive credential

**Hugging Face Embeddings node**
- Click the node
- Select your HuggingFace credential

**Supabase Vector Store node**
- Click the node
- Select your Supabase credential
- Confirm table name is `university_knowledge`

---

## 7. Configure the retrieval workflow

Open the retrieval workflow. Update three nodes:

**OpenRouter Chat Model node**
- Click the node
- Select your OpenRouter credential
- Model is set to `openai/gpt-4o-mini` — keep this
  or swap to any model available on OpenRouter

**AI Agent node**
- Click the node
- Update the system prompt — replace "Ibadat International
  University" with your institution name
- Keep the instruction to use the tool and refuse
  off-topic questions

**Supabase Vector Store node**
- Click the node
- Select your Supabase credential
- Confirm table name is `university_knowledge`
- Confirm query name is `match_university_knowledge`

**Embeddings HuggingFace Inference node**
- Click the node
- Select your HuggingFace credential
- Keep the model as `sentence-transformers/all-MiniLM-L6-v2`
  — this must match the ingestion pipeline exactly

---

## 8. Run ingestion

Go to the ingestion workflow and click **Execute Workflow**.

Watch each node — they should all turn green. If any node
fails, click it to see the error message.

After it completes, go to Supabase → Table Editor →
`university_knowledge`. You should see rows with content
text and embedding vectors. If rows are there, ingestion
worked.

> **HuggingFace cold start** — if the HuggingFace node
> times out on first run, wait about 20 seconds and
> execute again. The free inference API puts models to
> sleep after inactivity. Second run will be fast.

---

## 9. Go live

Go to the retrieval workflow. Toggle **Active** in the
top right corner.

Click on the **Chat Trigger** node — you will see the
public chat URL. Open it in any browser. Your assistant
is live.

Share that URL with your students. No login required,
works on mobile and desktop.

---

## Updating the knowledge base

When your documents change, update your Google Drive
file and re-run the ingestion workflow. New chunks will
be inserted into the table.

If you want to replace the knowledge base entirely
rather than add to it, clear the table first:

```sql
DELETE FROM university_knowledge;
```

Run this in Supabase SQL Editor, then re-run ingestion.

---

## Changing the embedding model

Do not change the embedding model without rebuilding
the entire table. The ingestion and retrieval pipelines
must use the exact same model — document vectors and
query vectors must live in the same dimensional space
for cosine similarity to mean anything.

If you switch models, clear the table and re-run
ingestion with the new model.

---

## Troubleshooting

**HuggingFace node times out**
Free inference API cold start. Wait 20 seconds, try again.

**Supabase RPC function not found**
You skipped or the `rpc_function.sql` did not run correctly.
Go to Supabase SQL Editor and run it again.

**Vector dimension mismatch error**
The embedding model in ingestion and retrieval do not match.
Check both workflows use `sentence-transformers/all-MiniLM-L6-v2`.

**Agent not using the retrieval tool**
The tool description in the Supabase Vector Store node
may be too vague. Make it explicit — describe exactly
what kind of questions the tool can answer.

**Answers seem off or incomplete**
Your chunks may be too large or too small. The default
is 1000 characters with 150 overlap. If your document
has long dense paragraphs, try reducing chunk size to
800. If it has short bullet points, try increasing to 1200.

---

## Questions

Open an issue on the repo or reach out directly —
details in the README.
