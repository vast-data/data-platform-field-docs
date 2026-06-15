# Spark Ports

## Spark Cluster (Data Engine)

| Component | Description | IP Address | Port(s) | Notes |
|---|---|---|---|---|
| Spark Master | The main control node of the cluster. | `master IP` | 2424 | Used for internal communication with workers and for drivers to connect to submit jobs. |
| Spark History Server | Detailed view of a specific Spark application. It's like a dashboard for that individual application, showing you how it's performing and helping you troubleshoot any issues. | `master IP` | 18080 |  |
| Spark Master UI | Web interface for monitoring the master. | `master IP` | 9292 |  |
| Spark Workers UI | Web interfaces for Spark worker nodes. | `worker IPs` | 9293 | Each worker node has its own UI instance. |

See [Spark UI proxying](./spark_ui_proxying.md) for an example proxy setup to access the Spark UIs.

## Spark Driver 

These are ports that need to be open for the Spark Master/Workers to communicate to the driver.

| **Component**       | **Description**                                                              | **IP Address** | **Port(s)**   | **Notes**                                                                                     |
|----------------------|------------------------------------------------------------------------------|----------------|---------------|-----------------------------------------------------------------------------------------------|
| Spark Driver RPC     | Port used for communication between the master/workers and the driver.       | Driver IP      | Static (e.g., 5000) | Configurable via `spark.driver.port`.                                                         |
| Spark Block Manager  | Port used by executors and workers to transfer shuffle and cached data.      | Driver IP      | Static (e.g., 5001) | Configurable via `spark.blockManager.port`.                                                   |

- **Static Ports Recommended**: Using static ports is ideal for Docker environments to simplify port mapping and avoid conflicts.
- **Essential Ports**: The master and workers need access to the **Driver RPC Port** and the **Block Manager Port** for control and data communication.
- **Docker Port Mapping**: Map these ports in your docker-compose.yml or Docker run command to ensure proper networking.
- **Configuration Example**: 
```python
  spark = (
    SparkSession.builder
    .appName("SparkConnectionTest")
    .config("spark.driver.port", "5000")
    .config("spark.blockManager.port", "5001")
    ...
  )
```