# Get PAT from DataBricks service
virtualenv -p /usr/bin/python2.7 databrickscli
source databrickscli/bin/activate
pip install databricks-cli
databricks configure --token


databricks clusters create --json "
{\"cluster_name\": \"autoscaling-cluster\",
\"spark_version\": \"4.0.x-scala2.11\",
  \"node_type_id\": \"Standard_D3_v2\",
  \"autoscale\" : {
    \"min_workers\": 2,
    \"max_workers\": 50
  },
  \"autotermination_minutes\":120
}"


databricks libraries install --maven-coordinates Azure:mmlspark:0.16 --cluster-id
databricks libraries install --maven-coordinates com.microsoft.azure:azure-eventhubs-spark_2.11:2.3.11 --cluster-id
