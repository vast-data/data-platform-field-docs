# Tagging Datastore S3 Objects

* NIFI Dataflow Overview  
* ListS3 Processor  
* SplitRecord  
* EvaluateJsonPath Processor  
* TAG S3 Processor  
* Validate the Objects are tagged:

## NIFI Dataflow Overview

To Tag Objects on the VAST Datastore automatically using NIFI the following steps are necessary

1. Configure ListS3 Processor
2. Configure SplitRecord Processor
3. Configure EvaluateJsonPath Processor
4. Configure TagS3Object Processor

![flow](./flow.png)

## ListS3 Processor

![s3 processor 1](./list_s3processor_1.png)
![s3 processor 2](./list_s3processor_2.png)

- **Bucket:** Your VAST Datastore View
- **Write Object Tags**: Set it to true to get Object Tags information from your S3 Objects
- **Endpoint Override**: Should include your VAST Datastore Endpoint
- **Prefix**: The S3 “Folder” that contains your objects
- **AWS Credentials Provider**: Enter your Access & Secret key into the Credential Provider

![aws credentials provider](./aws_creds_provider.png)

## SplitRecord

We are getting a List of Objects from the List S3 Processor and we need to split the list into single records

Records per Split \= 1

![split records](./split_records_1.png)

JSONTreeReader Settings:

![JSONTreeReader Settings](./json_treereader_settings.png)

JSONRecordSetwriter Settings:

![JSONRecordSetwriter Settings](./json_recordwriter_settings.png)

## EvaluateJsonPath Processor

We need to extract the object key for each of the records, so that we are able to tag the object by key properly

![EvaluateJsonPath Processor](./evaluate_json_path_settings.png)

## TAG S3 Processor

We need to specify the Tag Key and the Tag Value that we want to assign to our object.

Make sure to setup the AWS Credential Provider and te Endpoint Override URL. Also specify the Bucket where your Objects are stored accordingly

![TAG S3 Processor](./tag_s3_processor.png)

Execute the Pipeline: You need to make sure to a Processors to capture the Log Messages for each step of the Pipeline:

Add a Processor and use the Log Message.

![LogMessage Processor](./log_message.png)

## Validate the Objects are tagged

The following example code can be adjusted with the settings of your environment to get Object Tags from an Object.

```python
import boto3  
from botocore.exceptions import NoCredentialsError  
  
def list_tags_of_s3_object(access_key, secret_key, endpoint_url, bucket_name, key):  
	# Create an S3 client with custom configurations  
	s3 = boto3.client(  
    	's3',  
    	aws_access_key_id=access_key,  
    	aws_secret_access_key=secret_key,  
    	endpoint_url=endpoint_url,  
    	verify=False  # Set to False to disable SSL verification  
	)  
   
	# Get the tags associated with the S3 object  
	response = s3.get_object_tagging(  
    	Bucket=bucket_name,  
    	Key=key  
	)  
   
	return response['TagSet']  
   
if __name__ == "__main__":  
	# Replace these values with your AWS credentials, S3 endpoint, bucket name, and object key  
	aws_access_key = 'youraccesskey'  
	aws_secret_key = 'yoursecretkey'  
	s3_endpoint = 'http://172.200.201.9'  # e.g., 'https://s3.example.com'  
	bucket_name = 'datastore'  
	object_key = 'sko_nyc_taxi/2019-06.data.parquet'  
   
	try:  
    	object_tags = list_tags_of_s3_object(aws_access_key, aws_secret_key, s3_endpoint, bucket_name, object_key)  
    	  
        # Print the tags associated with the S3 object  
    	print(f"Tags for S3 object: s3://{bucket_name}/{object_key}")  
    	for tag in object_tags:  
        	print(f"Key: {tag['Key']}, Value: {tag['Value']}")  
        	  
    except NoCredentialsError:  
    	print("AWS credentials not available.")  
	except Exception as e:  
    	print(f"Error listing tags: {e}")
```

This functionality in NiFi is ideal for tracking newly ingested data, ensuring it is properly tagged and governed. You can configure attributes such as:

- **Data Owner**
- **Data Origin** (e.g., if pulling data from multiple sources)
- **Business Department**

These are just a few examples that can enhance data discovery and governance.

The VAST Catalog will include the tags once it has been refreshed, allowing you to filter, organize and report data based on those tags.