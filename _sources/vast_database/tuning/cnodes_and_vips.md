# CNODES and VIPs

## CNodes

Aim for a ratio of 4:1 CNode to DNodes for Database workloads.  That is for every DNode, there should be 4 CNodes.

## Virtual IP's

Use either 2 or 4 VIPs per CNode.

* **2 VIPs/CNode (Minimum):**
    * Handles normal data traffic.
    * Provides basic redundancy.
* **4 VIPs/CNode (Recommended):**
    * Optimizes data rebalancing during scaling.
    * Increases rebalancing speed and concurrency.
    * Reduces performance impact during rebalance.
    * Increases network throughput.
* **Why Rebalancing?**
    * Maintains balanced workload after adding/removing CNodes.
    * Ensures optimal performance.
* **Best Practice:** 
    * Use 4 VIPs/CNode for production to ensure smooth scaling.
