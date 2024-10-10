# Tuning

<font color='red'><b>NOTE:</b> This documentation is currently under review. Please be aware that the information contained here is subject to change as we finalize our recommendations.
</font>

## **Splits and Subsplits**

### Overview

In data processing, **splits** and **subsplits** are techniques used to divide large datasets into smaller chunks that can be processed concurrently. This improves query performance and optimizes resource usage in distributed or parallel processing environments.

### Terminology

- **Splits**: A split refers to dividing a dataset into disjoint subsets (usually rows) that can be processed independently in parallel by different workers.
- **Subsplits**: Further division of splits to allow more granular parallel processing. Subsplits enable fine-grained control over how data is processed by splitting each "split" into smaller subsets.

### **Query Configuration Parameters**

The `QueryConfig` dataclass defines the settings related to splits, subsplits, and parallel query execution.

#### 1. `num_splits` (Optional)
- The number of **splits** determines how the table is divided into disjoint subsets of rows for concurrent processing.
- If not set explicitly, the number of splits will be estimated based on the total row count of the table (See: `rows_per_split`).
- **Purpose**: This allows multiple RPCs (Remote Procedure Calls) to work concurrently on different parts of the table, speeding up query execution.

#### 2. `num_sub_splits` (Default: 4)
- Specifies the number of **subsplits** that are created from each split.
- Increasing the number of subsplits allows finer control of data processing and can lead to performance improvements, especially in environments that benefit from higher concurrency.
 
#### 3. `limit_rows_per_sub_split` (Default: 128 * 1024 rows)
- Defines how many rows a **subsplit** can process before it completes and sends the data back to the client.
- **Use Case**: This limit helps in controlling the granularity of each subsplit and can impact the responsiveness and parallelism of the query.

#### 4. `num_row_groups_per_sub_split` (Default: 8)
- Specifies how many **row groups** each subsplit reads continuously before skipping.
- **Row groups** are subsets of rows stored together for optimized I/O.
- **Note**: To use semi-sorted projections, this value must remain at `8`, as this is the hardcoded size of a row group per block in certain databases.

#### 5. `use_semi_sorted_projections` (Default: `True`)
- When enabled, this setting leverages **semi-sorted projections** to optimize query execution based on the sort order of the data.
- Semi-sorted projections allow faster access to rows with certain values and improve query performance.
 
#### 6. `semi_sorted_projection_name` (Optional)
- Specifies a particular semi-sorted projection to use if the `use_semi_sorted_projections` flag is enabled.
- **Use Case**: If you have a specific projection in mind, it can be set here to enforce its usage during query execution.

#### 7. `rows_per_split` (Default: 4,000,000)
- Used to estimate the number of splits based on the total row count. This value is not used if `num_splits` is set.
- **Example**: If a table has 20,000,000 rows and the `rows_per_split` is set to 4,000,000, the system will estimate 5 splits.
 
#### 8. `queue_priority` (Optional)
- A non-negative integer used for prioritizing queries on the server-side.
- Lower values mean higher priority, and if unset, the request is added to the end of the queue.

#### 9. `data_endpoints` (Optional)
- A list of strings representing endpoints.
- Each endpoint will be handled by a separate worker thread.
- A single endpoint can be specified more than once to benefit from multithreaded execution.

### **Example Use Case 1**
Let’s say you have a large table with 10 million rows. You want to execute a query that splits this table into smaller chunks, each of which is processed concurrently. You also want to ensure that each subsplit processes a limited number of rows before sending the results back.

Here’s how you might configure it:

```python
from vastdb.config import QueryConfig

config = QueryConfig(
	num_splits=10,                	  # Manually specify 10 splits
	num_sub_splits=5,             	  # Each split will be divided into 5 subsplits
	limit_rows_per_sub_split=50000,   # Each subsplit will process 50,000 rows at a time
)
```

In this configuration:
- The dataset will be split into 10 parts, and each split will be further divided into 5 subsplits.
- Each subsplit will process 50,000 rows before sending results back.
- Semi-sorted projections are used to improve performance based on the sorted nature of the data.

### **Example Use Case 2**
Let’s say you have a large table with 10 million rows. You want to execute a query that returns only a small set of rows, similar to the SQL LIMIT operator (e.g. `SELECT * FROM table LIMIT n`).

Here’s how you might configure it:

```python
from vastdb.config import QueryConfig

config = QueryConfig(
	num_splits=1,                	    # Manually specify 1 split
	num_sub_splits=1,             	  # Each split will be divided into 1 subsplits
	limit_rows_per_sub_split=10,   # Each subsplit will process 10 rows at a time
)
```

Here's how it can be used:

```python
import pyarrow
import vastdb

session = vastdb.connect(
    endpoint=ENDPOINT, access=ACCESS_KEY, secret=SECRET_KEY
)

with session.transaction() as tx:
    table = tx.bucket(DB_BUCKET).schema(DB_SCHEMA).table(DB_TABLE)

    batches = table.select(config=config)
    first_batch = next(batches)

    assert first_batch.num_rows == 10
```

### **Advanced Configuration**
- **Benchmarking**: You can disable semi-sorted projections (`use_semi_sorted_projections = False`) for benchmarking purposes to compare performance without optimizations.
- **Endpoint Configuration:** You can specify the endpoints using the data_endpoints parameter to control where each split is processed.

### **Conclusion**
Splits and subsplits enable parallel query processing by breaking down large datasets into smaller chunks. By adjusting parameters such as `num_splits`, `num_sub_splits`, and `limit_rows_per_sub_split`, you can fine-tune the performance and concurrency of queries, making them highly scalable for large datasets.
