# Salesforce to VAST DB

![Overview](./overview.png)

To get data from Salesforce into the VAST Database, you can follow these steps, leveraging tools like Nifi, Airbyte, Meltano, and VAST's integration options:

## Extract Data from Salesforce

- **Nifi, Airbyte, Meltano:** Use any of these tools to connect with Salesforce via its API to extract data. All three platforms support Salesforce as a source and can automate the data extraction process.

## Land Data into VAST Datastore

- **Nifi:**
  - Use the community-supported **vastdb driver** for Nifi to build data flows that land the data directly into the VAST Database.
  - Alternatively, use Nifi to move data into the **VAST S3 Datastore**, which allows scalable storage before loading into the VAST Database.

- **Airbyte / Meltano:**
  - These tools can also land the extracted data into the VAST S3 Datastore. For more advanced ETL options, you can push this data to an intermediary step (like staging).

## ETL from VAST Datastore to VAST Database

- Once the data is in the VAST S3 Datastore, you can use **Trino, Spark**, or the **Python API** to perform ETL (Extract, Transform, Load) processes to load the data into the VAST Database.

- These ETL processes can handle data transformations, schema management, and data migration into the target tables within VAST DB.

## Direct Database Ingestion via Nifi (Optional)

- As an alternative, Nifi can also use the **vastdb driver** to land data **directly into the VAST Database** without passing through the S3 Datastore, simplifying the data pipeline.

This approach offers flexibility depending on the tools you prefer and the complexity of your pipeline.

The VAST Database NIFI driver can be found here: [https://github.com/vast-data/vastdb\_nifi/blob/main/README.md\#docker-run](https://github.com/vast-data/vastdb_nifi/blob/main/README.md#docker-run).

Please note that this is a **community supported** project containing NiFi 2.0.0 Python Processors for Vast DataBase:

## Direct Ingest from SFDC into VAST Database using Nifi

**Prepare Steps on your Salesforce Instance:**

1. Click on Setup → App Manager → New Connect App
2. Enable Oauth Settings and provide the settings listed below and click save:

![Oauth Settings](./oauth_settings.png)

3. Click on Manage Consumer Details to get the Consumer Access and Secret

![Consumer Details](./consumer_details.png)

4. Allow access to the Oauth Endpoints in the Trusted IP Range for OAuth Web Server Flow
5. Create your access token My Profile → Reset My Security Token
6. Get your security token via Email
   - Note: To Authenticate using Oauth you would need The Consumer Access \+ Secret Key as well as user account name, and the concatenation of your users password \+ my access token without any spaces.
7. Test your Salesforce Oauth Credentials using the following curl command:


```
curl https://vastdata3-dev-ed.develop.my.salesforce.com/services/oauth2/token \  
-d "grant_type=password" \ 
-d "client_id=<your-sfdc-account-key>" \
-d "client_secret=<your-sfdc-secret-key>" \
-d "username=<your-salesforce-username>" \
-d "password=<salesforce-password>+<your token>"
```

### Step 1: Install and Set Up Apache Nifi

1. **Install Nifi** on your environment if you haven’t already. You can download it from [Apache Nifi](https://nifi.apache.org/download.html).

### Step 2: Install Nifi Processors for Salesforce and VAST DB

1. **Install Salesforce Processor**:
   - The `QuerySalesforceObject` processor allows you to fetch data from Salesforce.
   - The documentation for the processor is available [here](https://nifi.apache.org/docs/nifi-docs/components/org.apache.nifi/nifi-salesforce-nar/1.27.0/org.apache.nifi.processors.salesforce.QuerySalesforceObject/index.html).

2. **Install VAST DB Processor**:
   - Use the community-supported [VAST DB Processor](https://github.com/vast-data/vastdb_nifi/blob/main/docs/PutVastDB.md).
   - Download the VAST DB processor by following the instructions in the provided GitHub link and add it to Nifi.

### Step 3: Configure the Salesforce Processor (QuerySalesforceObject)

1. In Nifi, drag the `QuerySalesforceObject` processor onto the canvas.
2. **Set up the following properties** in the processor:
   - **Salesforce Authentication Information**: Provide the `Client ID`, `Client Secret`, `Username`, `Password`, and `Security Token` from your Salesforce account.
   - **Object Query**: Define the SOQL query to fetch the data you need from Salesforce.
   - **Output Type**: Set it to `JSON` to facilitate the flow to the next processor.

### Step 4: Configure VAST DB Processor (PutVastDB)

1. Drag the `PutVastDB` processor onto the canvas.
2. **Configure the following properties**:
   - **Host**: Enter your VAST Database host Vips.
   -  **Port**: Set the port for VAST DB (default is 80, but configure based on your setup).
   - **Username and Password**: Provide the credentials to connect to VAST DB.
   - **Database**: Specify the target database where the data will be stored.
   - **Table**: Enter the destination table name in VAST DB.
3. Configure the data mapping between the JSON output from Salesforce and the columns in your VAST DB table.

### Step 5: Connect Processors

1. **Connect** `QuerySalesforceObject` **to** `PutVastDB`: Ensure that the data fetched from Salesforce flows into the VAST DB processor.
2. Set up any intermediate processors like `ConvertRecord` or `SplitJson` if needed to handle the data format.

### Step 6: Run the Nifi Data Flow

1. Once everything is configured, start the processors by selecting them and clicking the start button.
2. Nifi will query Salesforce, retrieve the data, and then push it into the VAST Database.

### Step 7: Monitor and Debug

1. Monitor the data flow using the Nifi UI.
2. Check the logs for any errors and ensure the data lands in the correct VAST DB table.

This setup provides a direct integration pipeline from Salesforce to VAST DB using Nifi.


## Example NiFi Flow

{Download}`Example NiFi Flow<./NiFi_Flow.json>`