# ⚖️ PakConstitution AI

> **Pakistan's Constitution, made accessible through AI.**

A RAG-powered (Retrieval-Augmented Generation) constitutional assistant that lets lawyers, law students, journalists, and political analysts ask questions about Pakistan's constitution and receive **grounded, factual answers with exact article references** — powered by Gemini AI.

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![ChromaDB](https://img.shields.io/badge/ChromaDB-FF6B6B?style=flat)](https://www.trychroma.com)
[![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)](https://docker.com)
[![Gemini](https://img.shields.io/badge/Gemini-4285F4?style=flat&logo=google&logoColor=white)](https://aistudio.google.com)

---

## 📱 Try the App

**Download APK (Android):** [PakConstitution AI v1.0](https://drive.google.com/file/d/1hyPG4bA9XwPFXcCMxK9rJEHqbPIarCBr/view?usp=sharing)

> ⚠️ To use the app you need a running backend. See [Setup](#-setup) below.

---

## ✨ Features

- **Exact article citations** — every answer references specific article numbers and titles
- **Part & Chapter context** — answers include constitutional location (e.g. Part II - Fundamental Rights)
- **Amendment history** — queries like "what changed in the 18th amendment" search dedicated amendment data
- **Article range queries** — ask "what are articles 65 to 70" and get all of them
- **Conversation memory** — efficient context via summaries, not full message history
- **Dark/Light themes** — full chat UI with markdown rendering
- **Cross-platform** — one Flutter codebase for Android, iOS, Web, and Desktop

---

## 🏗️ Architecture

```
Flutter App
    ↓  POST /chat
FastAPI (RAG Pipeline)
    ↓  embed query          ↓  generate answer
sentence-transformers    gemini-flux → Gemini API
    ↓  vector search
ChromaDB
  ├── pakistan_constitution  (666 chunks)
  └── pakistan_amendments    (114 chunks)
```

All services run in isolated Docker containers — zero dependency conflicts.

---

## 📦 Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Frontend | Flutter | Cross-platform UI |
| Backend | FastAPI | RAG pipeline & API |
| LLM | Gemini via gemini-flux | Answer generation |
| Embeddings | sentence-transformers (all-MiniLM-L6-v2) | Vector encoding |
| Vector DB | ChromaDB | Semantic search |
| Deployment | Docker + Docker Compose | Containerization |

---

## 📊 Data

**Constitution source:** Official PDFs from [National Assembly of Pakistan](https://www.na.gov.pk) (updated November 2025)

**Processed data:**
- `data/final_chunks_2025.json` — 333 articles (2025 version)
- `data/final_chunks_2024.json` — 333 articles (2024 version)
- `data/v2_amendment_chunks.json` — 114 amendment change records (Amendments 1–21)

**Coverage:**
- Pakistan Constitution 1973 with all 27 amendments
- Articles 1–280+ with Part/Chapter metadata
- Amendment history for Amendments 1st through 21st

> 📁 Raw data scraped and structured by **[Abdul Ahad](https://github.com/abdulahad112)** — see [Contributors](#-contributors)

---

## 🚀 Setup

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (for building the app)
- Gemini API keys — get free keys at [Google AI Studio](https://aistudio.google.com/app/apikey)

### 1. Clone the repository

```bash
git clone https://github.com/malikasana/pakconstitution-ai.git
cd pakconstitution-ai
```

### 2. Set up environment

```bash
cp .env.example .env
```

Edit `.env` and add your Gemini API keys:

```env
GEMINI_KEY_1=AIza...
GEMINI_KEY_2=AIza...
GEMINI_MODE=both
GEMINI_LOG=true
GEMINI_FLUX_URL=http://gemini_flux:8000
```

> 💡 More keys = higher rate limits. Get up to 8 free keys across 2 Google accounts for ~10,800 requests/day.

### 3. Start the backend

```bash
cd pakconstitution
docker-compose up --build
```

First run takes 10–30 minutes (downloads models and embeds all articles). Subsequent starts use:

```bash
docker-compose start
```

### 4. Connect the Flutter app

Open `rag_frontend_and_management/lib/services/api_service.dart` and update the base URL, or enter it in the app's Settings panel at runtime.

**Local network:** `http://YOUR_PC_IP:8002`
**Public (ngrok):** Run `ngrok http 8002` and use the forwarding URL

---

## 🌐 Sharing with Others (ngrok)

```bash
ngrok http 8002
```

Share the forwarding URL. Anyone can use your backend as long as your PC and Docker are running.

---

## 📁 Project Structure

```
pakconstitution-ai/
├── pakconstitution/              # Backend
│   ├── docker-compose.yml
│   ├── .env.example
│   ├── data/                     # JSON chunks (add manually)
│   ├── embedder/
│   │   ├── Dockerfile
│   │   └── embed.py              # Embedding pipeline
│   ├── fastapi_service/
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── main.py               # RAG pipeline & API
│   ├── chromadb_service/
│   │   └── Dockerfile
│   └── gemini-flux/              # LLM key manager
└── rag_frontend_and_management/  # Flutter frontend
    ├── lib/
    │   ├── main.dart
    │   ├── services/api_service.dart
    │   ├── models/
    │   ├── providers/
    │   └── screens/
    └── pubspec.yaml
```

---

## 🗺️ Roadmap

| Version | Status | Features |
|---------|--------|---------|
| V1 | ✅ Done | Core RAG, Flutter UI, Docker, ngrok |
| V2 | ✅ Done | Better data quality, Part/Chapter metadata, amendment collection |
| V3 | 🔜 Planned | Full 1973–2025 amendment history, before/after comparison |
| V4 | 🔜 Planned | Global constitution expansion |

---

## 👥 Contributors

| Contributor | Role |
|-------------|------|
| **[Malik Asana](https://github.com/malikasana)** | Project lead, system architecture, backend, gemini-flux library |
| **[Abdul Ahad](https://github.com/abdulahad112)** | Data engineering — scraped, structured and organized the constitutional data including all 27 amendment files and part-by-part constitution text from pakistani.org |

> Special thanks to Abdul Ahad for the raw data pipeline that made V2 data quality possible. The structured `parts/` and `amendments/` folders were his work.

---

## ⚠️ Disclaimer

This app is for informational and educational purposes only. It is not a substitute for professional legal advice. Always consult a qualified lawyer for legal matters. While we strive for accuracy, constitutional text may contain extraction artifacts.

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

## 🔗 Related

- [gemini-flux](https://github.com/malikasana/gemini-flux) — Smart Gemini API key rotation library used in this project
- [pakistani.org](https://www.pakistani.org/pakistan/constitution/) — Constitutional text source
- [National Assembly of Pakistan](https://www.na.gov.pk) — Official constitution PDFs
