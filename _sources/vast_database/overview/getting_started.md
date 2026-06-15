# Getting Started

This documentation provides a quick start guide to using the VAST Web UI for creating and managing VAST Databases. We'll walk you through the essential steps to set up a dedicated VIP pool, configure a database owner user, and create a database and schema.

By following these steps, you'll have a solid foundation for using VAST Database to store and manage your data.

```{seealso}
The official documenation for configuring the Vast Database on a Vast Cluster can be found here: 

- [Release 5.0](https://support.vastdata.com/s/article/UUID-6e4e2b57-cf7b-8e8d-e382-9fe87ba7b3de)
- [Release 5.1](https://support.vastdata.com/s/article/UUID-e45ec1c7-c33f-056c-2e74-bb4046234be0)
```

## Setup steps

### Creating a Dedicated VIP Pool

A VIP pool is a group of CNodes (compute nodes) that serve specific workloads. By creating a dedicated VIP pool for VAST Database, you can ensure optimal performance for database operations.

1. **Navigate to Network Access:** In the VAST Web UI, go to **Network Access** -> **Virtual IP Pools**.
2. **Create a New VIP Pool:** Click the **+ Create VIP Pool** button.
3. **Configure Settings:**
   * **Name:** Give the VIP pool a descriptive name (e.g., "VastDB-VIP-Pool").
   * **CNodes:** Select the CNodes you want to include in the pool. Consider factors like workload balance and performance requirements.
   * **Other Options:** Set any additional options as needed (e.g., health checks, failover settings).
4. **Save:** Click **Create** to save the new VIP pool.

### Setting Up a Database Owner User

A database owner user has specific permissions to manage databases and schemas. Ensure the user you choose has the necessary privileges.

1. **Create or Select a User:** If you don't have a suitable user, create one. Go to **User Management** -> **Users** and click **+ Create User**.
2. **Grant Permissions:**
   * **Allow Create Bucket:** Ensure this option is enabled in the user's settings.
   * **S3 Access Key Pair:** Generate an S3 access key pair for the user. This is required for database authentication.

### Creating a Database and Schema

A database is a logical container for schemas and tables, while a schema is a collection of related tables.

1. **Navigate to VAST DB:** Go to **Database** -> **VAST DB**.
2. **Create a New Database:** Click **+ New Database**.
3. **Configure Settings:**
   * **Database Name:** Choose a unique name for the database (e.g., "my_database").
   * **Policy:** Select a policy that aligns with your database's security and performance requirements.
   * **Path:** Specify the path where the database will be stored.
   * **Database Owner:** Select the database owner user you created earlier.
4. **Create Schema:** Once the database is created, select it and click **+ Add Schema**. Choose a name for the schema (e.g., "public").

By following these steps, you'll have a well-configured VAST Database environment ready for your applications.

## Example automation

The following Python [code](../admin/vastdb_py_setup.ipynb) configures a Vast Database on a newly installed Vast Cluster using the Vast Cluster API.

<hr/>