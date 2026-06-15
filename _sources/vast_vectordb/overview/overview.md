# VAST Vector Database Overview

VAST Vector Database enables high-performance vector similarity search with SQL-based querying. It integrates vector operations into a standard database workflow, allowing you to combine vector search with traditional SQL filtering and ordering.

## Key Capabilities

**Vector Storage and Retrieval**
- Store high-dimensional vectors alongside structured data in tables
- Define vector columns with fixed dimensions using PyArrow list types
- Native support for vector similarity search operations

**SQL-Based Vector Search**
- Query vectors using standard SQL syntax
- Built-in distance functions:
  - `array_distance()` for Euclidean distance
  - `array_cosine_distance()` for cosine similarity
- Combine vector search with WHERE clauses for filtered queries
- Order results by similarity and limit top matches

**Integration**
- Uses PyArrow for data structures and Arrow tables for efficient data transfer
- ADBC (Arrow Database Connectivity) driver for querying
- VastDB SDK for table creation and data insertion
- Hierarchical organization: buckets → schemas → tables

## Common Use Cases

**Semantic Search**: Find similar items based on vector embeddings from text, images, or other data

**Recommendation Systems**: Retrieve similar products, content, or users based on embedding vectors

**Hybrid Search**: Combine vector similarity with traditional filters (timestamps, categories, metadata) in a single SQL query

**Time-Series Vector Data**: Store and query vectors with timestamps for temporal analysis

## Getting Started

The typical workflow involves:
1. Obtaining the ADBC driver (libadbc_driver_vastdb.so)
2. Creating tables with vector columns using the VastDB SDK
3. Inserting vector data with PyArrow tables
4. Querying with SQL and vector distance functions via ADBC

Vector columns are defined with fixed dimensions, and queries return Arrow tables that integrate seamlessly with pandas for analysis.

<hr/>
