# Splits and Subsplits

## Overview

Splits and subsplits are fundamental techniques used in parallel data processing to enhance query performance and optimize resource utilization. They involve dividing large datasets into smaller, manageable chunks that can be processed concurrently across multiple workers or processing units.

## Terminology

**Splits**: A split represents the primary division of a dataset into disjoint subsets, typically rows. These subsets are designed to be processed independently and in parallel by different workers. The number of splits determines the initial level of parallelism.

**Subsplits**: Subsplits are a further division of each split, allowing for more granular parallel processing. By breaking down each split into smaller subsplits, fine-grained control over data processing is achieved, leading to improved concurrency and performance, especially in environments with multiple processing cores.

## Purpose and Benefits

* **Parallelism**: Enables concurrent processing of data, significantly reducing query execution time.
* **Resource Optimization**: Distributes workload across multiple workers or cores, optimizing resource utilization.
* **Scalability**: Allows for efficient processing of large datasets by breaking them into smaller, manageable chunks.
* **Improved Performance**: Fine-grained control over data processing through subsplits leads to enhanced performance, particularly in high-concurrency environments.

## Configuration Parameters

The following parameters are typically used to configure splits and subsplits:

1.  Number of Splits (`num_splits`):
    * Determines the number of initial divisions of the dataset.
    * Allows for parallel processing across different workers.
    * May be estimated based on dataset size if not explicitly set.
    * Ideally should be divisible by number of workers for even workload distribution.
2.  Number of Subsplits (`num_sub_splits`):
    * Specifies the number of further divisions within each split.
    * Enables fine-grained parallel processing within each worker.
    * Should ideally be divisible by the number of cores per worker for optimal utilization.
3.  Rows per Subsplit (`limit_rows_per_sub_split`):
    * Defines the maximum number of rows processed by each subsplit before results are returned.
    * Controls granularity and responsiveness of the query.
4.  Rows per Split (`rows_per_split`):
    * Used to estimate the number of splits based on total row counts.
    * Not used if `num_splits` is set.
5.  Data Endpoints (`data_endpoints`):
    * List of endpoints where splits are processed.
    * Allows for distribution of workload across multiple processing nodes.

## Example Configuration

```
# Example configuration for splits and subsplits
num_splits = 64
num_sub_splits = 10
limit_rows_per_sub_split = 50000
data_endpoints = ["http://endpoint1", "http://endpoint2"]
```

## Conclusion

Splits and subsplits are essential techniques for parallelizing data processing and optimizing query performance. By carefully configuring the relevant parameters and considering optimization strategies, users can leverage these techniques to efficiently process large datasets and achieve significant performance improvements.
