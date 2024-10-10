# Tuning VAST DB for Trino

Example config:

```
vast: |-
  connector.name=vast
  endpoint=http://10.12.200.41
  region=us-east-1
  access_key_id={access}
  secret_access_key={[Vast Secret Key]}
  num_of_splits=64
  num_of_subsplits=10
  vast.http.client.request-timeout=60m
  vast.http.client.idle-timeout=60m
  data_endpoints=http://10.12.200.41,http://10.12.200.33
```

## Guidance Instructions for Parallelization Using Splits and Sub splits

`num_of_splits=64`

Parallelizing scans across the row ID space of the Vast table is achieved in two main levels. The first level is based on **splits**, which the **Trino query** engine understands and manages.

- **How splits work**: 
  - When a query is executed, the Trino coordinator communicates with the Vast connector to determine the number of splits to be used for the table. In this case, the recommended number of splits is 64.
  - For optimal efficiency, each split should process at least **4 million rows**. If the table contains, for instance, **256 million rows** or more, the system will utilize all 64 splits. Each split handles a distinct portion of the table, dividing it into 64 segments, allowing Trino to scan the table in parallel.

- **Parallelization across Trino tasks and RPCs**: Trino distributes these splits across its threads (known as tasks), and each split is sent as a set of Remote Procedure Calls (RPCs) that continuously scan that specific split of the table. This process enables parallel scanning of the data.

- **Distribution across data endpoints**: The splits are evenly distributed across data endpoints in a round-robin manner. This ensures that each data endpoint processes a unique split, allowing for efficient use of all available endpoints.

- **Utilization of compute nodes**: We recommend evenly distributing the data endpoints across the partitions of the compute nodes. This ensures that the full capacity of all compute nodes is utilized concurrently to handle the scan.

### Concept of Splits Summary

Splits divide the table for parallel processing, distributing the workload across Trino workers and compute nodes to maximize performance and efficiency.

`num_of_subsplits=10`

The second level of parallelism occurs within each split through the concept of subsplits.

- **How subsplits work**:
  - Once a split reaches a specific data endpoint, it can be further divided into subsplits. Since each compute node (C node) has multiple cores, subsplits allow for more granular division of the work. In this case, each split is broken into 10 subsplits.
  - Each subsplit represents a shard of the row ID space and is distributed to different cores within the compute nodes, allowing for parallel processing within the node.

- **Core utilization within compute nodes**: The subsplits ensure that all the cores within a compute node are efficiently utilized to process the split. Essentially, this provides two levels of parallelism:
  - Across data endpoints, controlled by the number of splits.
  - Within each data endpoint (or C node), controlled by the number of subsplits.

## Optimization Considerations

- **Splits and Trino workers**: To optimize performance, the number of splits should ideally be divisible by the number of Trino workers. This ensures that the workload is evenly distributed across all available workers, maximizing efficiency.
- **Subsplits and cores**: Similarly, the number of subsplits should be divisible by the number of cores available in each compute node. This allows for even workload distribution across all cores within the node.
- The system uses a heuristic based on estimated statistics from Vast to determine the row count for each Table.
- If statistics are available, the number of splits (64 in this case) is used as an upper limit. However, if the table is smaller, the system automatically reduces the number of splits accordingly, ensuring it doesn't exceed the upper limit of 64 splits.
- You want to aim for four million records per Split . If you try to go smaller you will get performance degradation in attempting to split that workload up

## Tables Statistics to Improve TRINO and its Cost based optimizer (CBO) 

1.	Run the Analyzer on the Tables:
o	If you haven't run the analyzer on the tables yet, it's recommended to do so. This helps optimize query performance.
2.	Purpose:
o	Running the analyzer can assist the Trino cost-based optimizer in selecting more efficient query execution plans, especially for joins.
3.	Outcome:
o	By analyzing the tables, you can potentially improve query performance by allowing the system to choose better optimization strategies for complex operations like joins.

## Common Options

![Common Options](./common_options.png "Common Options")
 
A common strategy for larger tables is to use a join that distributes the data efficiently across multiple nodes. However, for smaller tables, a broadcast join can be used, where all the data is grouped into a single node for processing.

`SET SESSION join_distribution_type = 'BROADCAST';`

These parameters control memory usage at the query level:

- **query.max-memory**: Description: Sets the maximum amount of distributed memory that a single query can use across all nodes. This is critical for preventing a single query from consuming too much memory and impacting other queries.
 - Example: `query.max-memory=30GB`

- **query.max-memory-per-node**: Description: Sets the maximum amount of memory that a single query can use on any single node. This helps in preventing one node from being overloaded by a specific query.
 - Example: `query.max-memory-per-node=5GB`

- **query.max-total-memory-per-node**: Description: Sets the maximum total memory (user memory + system memory) a single query can use per node. This includes both the memory used by the query itself and by the system to process the query.
 - Example: `query.max-total-memory-per-node=10GB`

## Sizing worker nodes for Vast workloads

When sizing worker nodes for Vast workloads, a general recommendation is to use fewer, larger nodes rather than many smaller nodes. This reduces data shuffling and improves performance. However, the optimal configuration depends on memory availability and the size of the tables being joined in memory.

For large data processing, more memory is required for joins. Trino can either perform joins in memory or use a "fail-safe" mode, where intermediate results are written to storage to avoid crashes, though this takes longer. The amount of memory needed depends on the size of the tables and the filtering applied by Vast before data is processed by Trino.

Filtering happens in Vast, and only relevant rows are passed to Trino. Trino's cost-based optimizer uses statistics to estimate the number of rows and determines the best join strategy. Analyzing tables helps improve memory usage estimation and optimization.

Additionally, using broadcast joins can reduce latency by minimizing data shuffling, particularly for join-heavy queries. Adjusting the max memory of worker nodes is important as memory is increased.

## Best Practice on Connecting BI Tools

- Superset → requires different vastdb schema separator
- Thoughtspot → required Information Schema for VAST DB, build into new connector list the fixed version.

