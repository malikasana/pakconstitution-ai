import os
import re
import time
import requests
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional
from sentence_transformers import SentenceTransformer
import chromadb
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

print("Loading embedding model...")
model = SentenceTransformer("all-MiniLM-L6-v2")

def get_collection():
    while True:
        try:
            client = chromadb.HttpClient(host="chromadb_service", port=8000)
            col = client.get_collection("pakistan_constitution")
            print("ChromaDB collection ready.")
            # Also get amendment collection if exists
            try:
                amdt_col = client.get_collection("pakistan_amendments")
                print("Amendment collection ready.")
            except Exception:
                amdt_col = None
                print("No amendment collection found.")
            return client, col, amdt_col
        except Exception as e:
            print(f"Waiting for ChromaDB... {e}")
            time.sleep(5)

chroma_client, collection, amendment_collection = get_collection()

GEMINI_FLUX_URL = os.getenv("GEMINI_FLUX_URL", "http://gemini_flux:8000")
print(f"gemini-flux at {GEMINI_FLUX_URL}")
print("FastAPI ready.")

def call_gemini(prompt: str) -> str:
    response = requests.post(
        f"{GEMINI_FLUX_URL}/generate",
        json={"prompt": prompt, "max_tokens": 8192, "temperature": 0.3},
        timeout=600
    )
    response.raise_for_status()
    return response.json()["response"]

class ChatRequest(BaseModel):
    message: str
    context: list = []

class Reference(BaseModel):
    article_number: str
    title: str
    excerpt: str
    amendment: str

class ChatResponse(BaseModel):
    answer: str
    summary: Optional[str] = None
    references: list[Reference]

def detect_article_range(question: str):
    range_pattern = re.search(
        r'articles?\s+(\d+)\s+(?:to|through|[-–])\s+(\d+)',
        question, re.IGNORECASE
    )
    if range_pattern:
        start = int(range_pattern.group(1))
        end = int(range_pattern.group(2))
        return list(range(start, end + 1))
    return []

def detect_single_article(question: str):
    single_pattern = re.search(r'article\s+(\d+[A-Za-z]*)', question, re.IGNORECASE)
    if single_pattern:
        return single_pattern.group(1).upper()
    return None

def is_comparative_query(question: str) -> bool:
    keywords = ["before", "old law", "changed", "previously", "used to",
                "amendment", "difference", "what was", "history",
                "before 26th", "before 18th", "original"]
    return any(k in question.lower() for k in keywords)

def is_amendment_query(question: str) -> bool:
    patterns = [
        r'\b\d+(st|nd|rd|th)\s+amendment\b',
        r'\bamendment\s+(number\s+)?\d+\b',
        r'\bwhat (changed|was changed|did.*change)\b',
        r'\bwhat (was|were) (added|inserted|omitted|substituted)\b',
    ]
    return any(re.search(p, question, re.IGNORECASE) for p in patterns)

def retrieve_chunks(question: str, top_k: int = 8) -> list:
    query_vector = model.encode([question]).tolist()

    # Amendment query — search amendment collection first
    if is_amendment_query(question) and amendment_collection:
        try:
            results = amendment_collection.query(
                query_embeddings=query_vector,
                n_results=min(top_k, 5)
            )
            if results["documents"][0]:
                amdt_chunks = [{
                    "text": results["documents"][0][i],
                    "metadata": results["metadatas"][0][i],
                } for i in range(len(results["documents"][0]))]
                # Also add constitution chunks for context
                const_results = collection.query(
                    query_embeddings=query_vector,
                    n_results=3,
                    where={"year": "2025"}
                )
                for i in range(len(const_results["documents"][0])):
                    amdt_chunks.append({
                        "text": const_results["documents"][0][i],
                        "metadata": const_results["metadatas"][0][i],
                    })
                return amdt_chunks
        except Exception as e:
            print(f"Amendment query error: {e}")

    # Range query
    article_range = detect_article_range(question)
    if article_range:
        all_chunks = []
        for art_num in article_range:
            try:
                results = collection.query(
                    query_embeddings=query_vector,
                    n_results=2,
                    where={"article_number_int": {"$eq": art_num}}
                )
                if results["documents"][0]:
                    picked = False
                    for j in range(len(results["documents"][0])):
                        meta = results["metadatas"][0][j]
                        if meta.get("year") == "2025":
                            all_chunks.append({
                                "text": results["documents"][0][j],
                                "metadata": meta,
                            })
                            picked = True
                            break
                    if not picked:
                        all_chunks.append({
                            "text": results["documents"][0][0],
                            "metadata": results["metadatas"][0][0],
                        })
            except Exception as e:
                print(f"Range query error for {art_num}: {e}")
                continue
        if all_chunks:
            return all_chunks

    # Single article query
    single_article = detect_single_article(question)
    if single_article:
        try:
            results = collection.query(
                query_embeddings=query_vector,
                n_results=2,
                where={"article_no": {"$eq": single_article}}
            )
            if results["documents"][0]:
                for j in range(len(results["documents"][0])):
                    meta = results["metadatas"][0][j]
                    if meta.get("year") == "2025":
                        return [{"text": results["documents"][0][j], "metadata": meta}]
                return [{"text": results["documents"][0][0], "metadata": results["metadatas"][0][0]}]
        except Exception as e:
            print(f"Single article query error: {e}")

    # Part/Chapter query
    part_keywords = {
        "fundamental rights": {"part": "II", "chapter": "Fundamental Rights"},
        "judicature": {"part": "VII"},
        "judiciary": {"part": "VII"},
        "parliament": {"part": "III", "chapter": "Parliament"},
        "president": {"part": "III", "chapter": "The President"},
        "election": {"part": "VIII"},
        "emergency": {"part": "X"},
        "islamic": {"part": "IX"},
    }
    for keyword, filters in part_keywords.items():
        if keyword in question.lower():
            try:
                where_filter = {"year": "2025"}
                if "part" in filters:
                    where_filter = {"$and": [{"year": "2025"}, {"part": {"$eq": filters["part"]}}]}
                results = collection.query(
                    query_embeddings=query_vector,
                    n_results=top_k,
                    where=where_filter
                )
                if results["documents"][0]:
                    return [{
                        "text": results["documents"][0][i],
                        "metadata": results["metadatas"][0][i],
                    } for i in range(len(results["documents"][0]))]
            except Exception as e:
                print(f"Part query error: {e}")
            break

    # Semantic search
    where_filter = None
    if not is_comparative_query(question):
        where_filter = {"year": "2025"}

    results = collection.query(
        query_embeddings=query_vector,
        n_results=top_k,
        where=where_filter
    )
    chunks = []
    for i in range(len(results["documents"][0])):
        chunks.append({
            "text": results["documents"][0][i],
            "metadata": results["metadatas"][0][i],
        })
    return chunks

def build_prompt(question: str, chunks: list, context: list) -> str:
    passages = ""
    for chunk in chunks:
        meta = chunk["metadata"]
        art_no = meta.get('article_no', '')
        title = meta.get('title', '')
        part = meta.get('part', '')
        chapter = meta.get('chapter', '')
        location = f"Part {part}" + (f" - {chapter}" if chapter else "") if part else ""
        passages += f"\n[Article {art_no}] {title}"
        if location:
            passages += f" ({location})"
        passages += f"\n{chunk['text']}\n"

    context_str = ""
    if context:
        for turn in context[-10:]:
            role = turn.get("role", "user")
            content = turn.get("content", "")
            context_str += f"{role.capitalize()}: {content}\n"

    return f"""You are a Pakistani constitutional law expert. Answer the question using the articles provided below. Always cite exact article numbers and Part/Chapter references. Be comprehensive.

Previous conversation:
{context_str}

Relevant Constitutional Articles:
{passages}

Question: {question}

Provide a complete detailed answer with exact article references. At the very end of your response on a new line write exactly:
SUMMARY: <one sentence summary of your answer for context memory>"""

def extract_summary(answer: str):
    if "SUMMARY:" in answer:
        parts = answer.rsplit("SUMMARY:", 1)
        return parts[0].strip(), parts[1].strip()
    return answer.strip(), answer[:150].strip()

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    chunks = retrieve_chunks(request.message)
    prompt = build_prompt(request.message, chunks, request.context)
    full_answer = call_gemini(prompt)
    answer, summary = extract_summary(full_answer)

    references = []
    for chunk in chunks:
        meta = chunk["metadata"]
        references.append(Reference(
            article_number=meta.get("article_no", ""),
            title=meta.get("title", ""),
            excerpt=chunk["text"][:200],
            amendment=meta.get("amendments_mentioned", meta.get("amendment_name", ""))
        ))

    return ChatResponse(answer=answer, summary=summary, references=references)

@app.get("/health")
def health():
    return {"status": "ok"}