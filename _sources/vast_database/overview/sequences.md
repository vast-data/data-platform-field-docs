# Sequences

## Implementing a Sequence-Like Column in VAST Database

If you need a column with sequence-like functionality in a VAST Database table—similar to `AUTO_INCREMENT` or `SEQUENCE` in other database systems—you can achieve this by exposing and controlling the table's internal row-id. This allows your application to manage data insertion in a specific order and perform efficient range-based queries.

Here’s how to implement and use this feature.

### Step 1: Expose the Row-ID

To begin, you must define a special column in your table schema that exposes the internal row-id. This column must have the following specific attributes:

  * **Column Name:** `vastdb_rowid`
  * **Data Type:** `int64`

By adding this column, you instruct VAST Database that you intend to interact with the row-id directly.

### Step 2: Manually Assign IDs During Insertion

With the `vastdb_rowid` column present, you can now specify the exact row where data should be inserted. Your application is responsible for generating the unique ID for each `INSERT` statement.

For example, to insert a new record at a specific ID, you would use a query like this:

```sql
INSERT INTO my_table (vastdb_rowid, user_data_col1, user_data_col2)
VALUES (1001, 'some_value', 'another_value');
```

This command places the new record at row `1001`.

```{attention} **Critical Limitation on Inserts**

It is essential to understand that once you start specifying the `vastdb_rowid` in an `INSERT` statement for a table, you must provide it for **all subsequent inserts** into that same table. You cannot mix insertion methods; you must either always let VAST allocate the row-id internally or always define it yourself.
```

### Step 3: Query Data Using the Row-ID

A key advantage of this approach is the ability to efficiently query specific ranges of rows, which is particularly useful for ordered data sets or partitioned information.

For example, to select all rows within a specific ID range:

```sql
SELECT * FROM my_table WHERE vastdb_rowid > 5000 AND vastdb_rowid < 5100;
```

This query will quickly retrieve all records with an ID between `5000` and `5100`.

Unlike the strict rule for `INSERT` statements, you have complete flexibility when querying. You can freely mix queries that filter by `vastdb_rowid` with queries that do not use it.