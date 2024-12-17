# Trino Query Time Merge (non-id)

**Handling Duplicates and Latest Updates with Trino**


```{seealso}
[Query Merge vs Insert Merge](./query_time_merge.md)
```

In this guide, we demonstrate how to manage duplicates at query time and retain the latest updates using **Trino SQL**. Similar to Apache Spark’s window functions, Trino’s **window functions** enable you to:  

- Partition the data based on a unique identifier or composite key (e.g., `id`, `first_name`, `last_name`).  
- Order the records by a timestamp (or another field to determine the most recent entry).  
- Assign row numbers to isolate and filter the latest record.  

By leveraging this approach, we can efficiently handle large datasets while ensuring that only the most up-to-date information is processed.

---

## 1. Sample Data  

Let’s assume we have a table `sample_data` with duplicate records:  

```sql
CREATE TABLE sample_data (
    id INTEGER,
    first_name VARCHAR,
    last_name VARCHAR,
    timestamp TIMESTAMP
);

INSERT INTO sample_data VALUES 
(1, 'Alice', 'Smith', TIMESTAMP '2024-11-18 10:00:00'),
(2, 'Bob', 'Johnson', TIMESTAMP '2024-11-18 11:00:00'),
(1, 'Alice', 'Smith', TIMESTAMP '2024-11-18 12:00:00'), -- Duplicate with later timestamp
(3, 'Charlie', 'Brown', TIMESTAMP '2024-11-18 09:00:00'),
(2, 'Bob', 'Johnson', TIMESTAMP '2024-11-18 12:00:00');   -- Duplicate with later timestamp
```

---

## 2. Remove Duplicates and Keep the Latest Record  

To remove duplicates and retain the most recent record for each unique combination of `id`, `first_name`, and `last_name`, we use Trino’s **window functions**.  

```sql
WITH ranked_data AS (
    SELECT 
        id,
        first_name,
        last_name,
        timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY id, first_name, last_name
            ORDER BY timestamp DESC
        ) AS row_num
    FROM sample_data
)
SELECT id, first_name, last_name, timestamp
FROM ranked_data
WHERE row_num = 1;
```

**Result:**  

| id | first_name | last_name | timestamp           |  
|----|------------|-----------|---------------------|  
| 1  | Alice      | Smith     | 2024-11-18 12:00:00 |  
| 2  | Bob        | Johnson   | 2024-11-18 12:00:00 |  
| 3  | Charlie    | Brown     | 2024-11-18 09:00:00 |  

---

## 3. Handling Composite Keys  

If you need to identify duplicates based on a combination of fields (e.g., `first_name` and `last_name` instead of `id`), you can adjust the `PARTITION BY` clause accordingly.  

For example, to handle duplicates based only on `first_name` and `last_name`:  

```sql
WITH ranked_data AS (
    SELECT 
        first_name,
        last_name,
        timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY first_name, last_name
            ORDER BY timestamp DESC
        ) AS row_num
    FROM sample_data
)
SELECT first_name, last_name, timestamp
FROM ranked_data
WHERE row_num = 1;
```

This approach is useful when a single identifier (`id`) is unavailable or if uniqueness is defined by a combination of attributes.  

---

## 4. Why is the Window Function Required?  

**a) Partitioning Data**  
The `PARTITION BY` clause groups the data by the specified keys (`id`, `first_name`, `last_name` or other composite fields).  

**b) Sorting Within Partitions**  
The `ORDER BY timestamp DESC` ensures the latest records appear first within each partition.  

**c) Row Number Assignment**  
The `ROW_NUMBER()` function assigns a unique rank to each record in the partition, starting with the most recent record.  

**d) Filtering for the Latest Record**  
Filtering where `row_num = 1` isolates the most recent record for each unique key combination.  

---

## 5. Optimizing Data Processing with Filters  

To optimize performance, apply filters before using window functions:  

- **Filter by Time Window**:  
  ```sql
  SELECT *
  FROM sample_data
  WHERE timestamp BETWEEN TIMESTAMP '2024-01-01' AND TIMESTAMP '2024-01-31';
  ```

- **Filter by Specific Entity**:  
  ```sql
  SELECT *
  FROM sample_data
  WHERE id = 12345;
  ```

---

## Conclusion  

In this guide, we demonstrated how to handle duplicates and retain the latest updates using Trino’s window functions. The process involves:  

- Partitioning data by a unique identifier or composite key (e.g., `id`, `first_name`, `last_name`).  
- Sorting records by a timestamp to identify the most recent entries.  
- Using `ROW_NUMBER()` to filter and keep only the latest record.  

This approach is flexible, efficient, and scalable, ensuring that large datasets are processed accurately to maintain only the most up-to-date information.  