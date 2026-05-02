# Ollama Local LLM Runtime

Ollama provides the local analysis model for assessment, report generation, and response planning.

The runtime is intentionally stateless. It analyzes evidence supplied in prompts through `/api/generate`; it does not learn or persist new security knowledge unless a future RAG pipeline supplies historical logs or embeddings as context.
