FROM python:3.10-slim

WORKDIR /app

RUN pip install sentence-transformers chromadb numpy

COPY embed.py .

CMD ["python", "embed.py"]