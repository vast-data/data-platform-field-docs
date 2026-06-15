# VAST Query Engine

The VAST Database includes a VAST Query Engine. This query engine provides improved performance for database operations. VAST Database clients can access the query engine using a VAST ADBC client library.

---

## VAST Query Engine Features

The VAST Query Engine supports the following:

* **Vector search.** The ability to query vectors in the database for the nearest neighbors.
* **Column Allow/Deny.** The ability to restrict access to columns and rows in a database based on a user's identity.
* **Filter pushdown.** This is an optimized scan/query of selected rows and/or columns in a database table.
* **Nested data types.** The ability to nest datatypes such as `struct`, `array`, and `map`.

---

## Accessing VAST Databases using the Query Engine

In order to access the VAST Database using the Query Engine, you will need the following:

* A VIP Pool dedicated to the Query Engine (see [Creating VIP Pools for the VAST Query Engine](#creating-vip-pools-for-the-vast-query-engine)).
* An S3 user with permission to access the Database, and with an Access & Secret key pair (the keys are used by the client application). See `Adding Local Users`.
* An S3 Identity or Bucket policy for the user that sets the permissions to access the database. See `Creating S3 User Policies`.
* A client application that uses the VAST Query Engine ADBC library to access the Query Engine (see [VAST Database Query Engine ADBC Driver for Client Applications](#vast-database-query-engine-adbc-driver-for-client-applications)).

---

(creating-vip-pools-for-the-vast-query-engine)=
## Creating VIP Pools for the VAST Query Engine

The Query Engine requires a dedicated VIP pool for client access. Create this pool with the role **Query Engine**, using the Product and Component Names: **Vast GUI**.

1.  Navigate to the **Network Access** page, and select **Virtual IP Pools**.
2.  Click **Create Virtual IP Pool**.
3.  Complete details for the VIP Pool following the procedure described in [Managing Virtual IP Pools](https://support.vastdata.com/s/document-item?bundleId=vast-cluster-administrator-s-guide5.3&topicId=managing-network-access/managing-virtual-ip-pools.html&_LANG=enus), selecting role type **Query Engine**. Also define a FQDN in the DNS for the VIP Pool (see `Managing Virtual IP Pools`).

---

(vast-database-query-engine-adbc-driver-for-client-applications)=
## VAST Database Query Engine ADBC Driver for Client Applications

VAST provides an open-source ADBC driver that you can use to provide access for your client application to the VAST Query Engine.

Download the driver from <https://github.com/vast-data/vastdb-adbc-driver>.  This link will be available soon.  In the meantime, please access a developerment version of the driver here:

- [version 2026861](../_static/libadbc_driver.so)

The ADBC can be used in a Linux x86_64 environment, for programming languages that have a driver manager (for example, C++, Rust, Python, Ruby, Go, and Java).

When using this driver, you will need to provide a VIP address and an access/secret key pair to access databases (see [Creating VIP Pools for the VAST Query Engine](#creating-vip-pools-for-the-vast-query-engine)).