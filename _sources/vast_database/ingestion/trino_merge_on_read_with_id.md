# Trino Query Time Merge (id)  

**Handling Duplicates and Latest Updates with Trino**

```{seealso}
[Query Merge vs Insert Merge](./query_time_merge.md)
```

In this guide, we demonstrate how to manage duplicates at query time and retain the latest updates using **Trino SQL**. Similar to Apache Spark’s window functions, Trino’s **window functions** enable you to:  

- Partition the data based on a unique identifier (`id`).  
- Order the records by a timestamp (or another field to determine the most recent entry).  
- Assign row numbers to isolate and filter the latest record.  

By leveraging this approach, we can efficiently handle large datasets while ensuring that only the most up-to-date information is processed.

---

## 1. Sample Data  

Let’s assume we have a table `sample_data` with duplicate records:  

```sql
CREATE TABLE sample_data (
    id INTEGER,
    name VARCHAR,
    timestamp TIMESTAMP
);

INSERT INTO sample_data VALUES 
(1, 'Alice', TIMESTAMP '2024-11-18 10:00:00'),
(2, 'Bob', TIMESTAMP '2024-11-18 11:00:00'),
(1, 'Alice Updated', TIMESTAMP '2024-11-18 12:00:00'), -- Duplicate ID with later timestamp
(3, 'Charlie', TIMESTAMP '2024-11-18 09:00:00'),
(2, 'Bob Updated', TIMESTAMP '2024-11-18 12:00:00');   -- Duplicate ID with later timestamp
```

---

## 2. Remove Duplicates and Keep the Latest Record  

To remove duplicates and retain the most recent record for each `id`, we use Trino’s **window functions**.  

```sql
WITH ranked_data AS (
    SELECT 
        id,
        name,
        timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY id 
            ORDER BY timestamp DESC
        ) AS row_num
    FROM sample_data
)
SELECT id, name, timestamp
FROM ranked_data
WHERE row_num = 1;
```

**Result:**  

| id | name          | timestamp           |  
|----|---------------|---------------------|  
| 1  | Alice Updated | 2024-11-18 12:00:00 |  
| 2  | Bob Updated   | 2024-11-18 12:00:00 |  
| 3  | Charlie       | 2024-11-18 09:00:00 |  

---

## 3. Why is the Window Function Required?  

**a) Partitioning Data**  
The `PARTITION BY id` groups the data by the `id` column. This allows each `id` to be processed independently, isolating duplicates within each group.  

**b) Sorting Within Partitions**  
The `ORDER BY timestamp DESC` sorts records within each partition, ensuring the most recent record is at the top.  

**c) Row Number Assignment**  
Using `ROW_NUMBER()` assigns a unique rank to each record based on the descending order of the timestamp. The most recent record for each `id` is assigned `row_num = 1`.  

**d) Filtering for the Latest Record**  
Finally, filtering where `row_num = 1` retains only the most recent record for each `id`, effectively eliminating duplicates.  

---

## 4. Optimizing Data Processing with Filters  

Processing the entire dataset might not always be necessary. To optimize performance, apply filters before using window functions:  

- **Filter by Time Window**:  
  Process only records within a specific time range:  

  ```sql
  SELECT *
  FROM sample_data
  WHERE timestamp BETWEEN TIMESTAMP '2024-01-01' AND TIMESTAMP '2024-01-31';
  ```

- **Filter by Entity**:  
  Focus on data for a specific entity:  

  ```sql
  SELECT *
  FROM sample_data
  WHERE id = 12345;
  ```

By applying these filters in your query, you reduce the dataset size and improve query performance.  

---

## Conclusion  

In this guide, we demonstrated how to handle duplicates and retain the latest updates using Trino’s window functions. The process involves:  

- Partitioning data by a unique identifier (`id`).  
- Sorting records by a timestamp to identify the most recent entries.  
- Using `ROW_NUMBER()` to filter and keep only the latest record.  

This approach is efficient and scalable, ensuring that large datasets are processed accurately to maintain only the most up-to-date information.