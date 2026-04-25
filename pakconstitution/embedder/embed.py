import re
import json
import os
import chromadb
from sentence_transformers import SentenceTransformer

DATA_DIR = "/data"
MODEL_NAME = "all-MiniLM-L6-v2"


def get_article_int(article_no: str) -> int:
    m = re.match(r'(\d+)', str(article_no))
    return int(m.group(1)) if m else 0


print("Loading chunks...")
constitution_chunks = []
for fname in ["final_chunks_2025.json", "final_chunks_2024.json"]:
    fpath = os.path.join(DATA_DIR, fname)
    if os.path.exists(fpath):
        with open(fpath) as f:
            constitution_chunks.extend(json.load(f))

amendment_chunks = []
amdt_path = os.path.join(DATA_DIR, "v2_amendment_chunks.json")
if os.path.exists(amdt_path):
    with open(amdt_path) as f:
        amendment_chunks = json.load(f)

print(f"Constitution chunks: {len(constitution_chunks)}")
print(f"Amendment chunks: {len(amendment_chunks)}")

print("Loading embedding model...")
model = SentenceTransformer(MODEL_NAME)
print(f"Model loaded. Dimension: {model.get_embedding_dimension()}")

print("Connecting to ChromaDB...")
client = chromadb.HttpClient(host="chromadb_service", port=8000)


# ── Constitution collection ───────────────────────────────────────────────────
constitution_done = False
try:
    col = client.get_collection("pakistan_constitution")
    count = col.count()
    if count >= len(constitution_chunks):
        print(f"Constitution collection already has {count} chunks. Skipping.")
        constitution_done = True
    else:
        print(f"Collection has {count} chunks, expected {len(constitution_chunks)}. Rebuilding...")
        client.delete_collection("pakistan_constitution")
except Exception:
    pass

if not constitution_done:
    print("Embedding constitution chunks...")
    texts = [c["text"] for c in constitution_chunks]
    embeddings = model.encode(texts, batch_size=64, show_progress_bar=True)

    collection = client.create_collection(name="pakistan_constitution")

    metadatas = [{
        "article_no": c["article_no"],
        "article_number_int": get_article_int(c["article_no"]),
        "title": c["title"],
        "source": c["source"],
        "year": c["year"],
        "part": c.get("part", ""),
        "part_number": c.get("part_number", "0"),
        "part_label": c.get("part_label", ""),
        "chapter": c.get("chapter", ""),
        "amendments_mentioned": c.get("amendments_mentioned", ""),
        "is_amended": c.get("is_amended", 0),
        "char_count": c["char_count"]
    } for c in constitution_chunks]

    ids = [f"{c['source']}_art{c['article_no']}" for c in constitution_chunks]

    collection.add(
        ids=ids,
        embeddings=embeddings.tolist(),
        metadatas=metadatas,
        documents=texts
    )
    print(f"Constitution collection: {collection.count()} chunks stored.")


# ── Amendment collection ──────────────────────────────────────────────────────
if amendment_chunks:
    amendment_done = False
    try:
        amdt_col = client.get_collection("pakistan_amendments")
        count = amdt_col.count()
        if count >= len(amendment_chunks):
            print(f"Amendment collection already has {count} chunks. Skipping.")
            amendment_done = True
        else:
            print(f"Amendment collection has {count} chunks, expected {len(amendment_chunks)}. Rebuilding...")
            client.delete_collection("pakistan_amendments")
    except Exception:
        pass

    if not amendment_done:
        print("Embedding amendment chunks...")
        amdt_texts = [c["text"] for c in amendment_chunks]
        amdt_embeddings = model.encode(amdt_texts, batch_size=64, show_progress_bar=True)

        amdt_collection = client.create_collection(name="pakistan_amendments")

        amdt_metadatas = [{
            "article_no": c["article_no"],
            "article_number_int": get_article_int(c["article_no"]),
            "amendment_number": c.get("amendment_number", ""),
            "amendment_name": c.get("amendment_name", ""),
            "amendment_year": c.get("amendment_year", ""),
            "change_type": c.get("change_type", ""),
            "source": c["source"],
            "year": c["year"],
            "char_count": c["char_count"]
        } for c in amendment_chunks]

        amdt_ids = [f"amdt_{c['amendment_number']}_art{c['article_no']}_{i}"
                    for i, c in enumerate(amendment_chunks)]

        amdt_collection.add(
            ids=amdt_ids,
            embeddings=amdt_embeddings.tolist(),
            metadatas=amdt_metadatas,
            documents=amdt_texts
        )
        print(f"Amendment collection: {amdt_collection.count()} chunks stored.")

print("Embedder finished. ChromaDB is ready.")