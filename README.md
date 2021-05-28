# Coding from scratch a realtime Azure data and AI pipeline
In just 60 minutes, this session will demonstrate an end to end data pipeline supplemented by AI to achieve insights real-time. Using components like Azure Logic Apps, Event Hubs, Databricks, Cognitive Services, and Power BI I'll be putting together a pipeline that takes our conference social stream and analyses it realtime. Join me as I show how quickly these sorts of systems can be put together for awesome insight. 

- [MS Build talk entry](https://mybuild.techcommunity.microsoft.com/sessions/77150)
- Prerecorded demo vids: [The Azure Side](https://www.youtube.com/watch?v=0mh9qIyp4SU), [The AI side](https://youtu.be/1XhdKjBXoxM)
- [Slides](https://sarahnightingalehq-my.sharepoint.com/:p:/g/personal/steph_nightingalehq_ai/EUKk4TanSB5Lq9Fb2OYXbjoB92e29yAe3Hw6RkqPn6wBzQ?e=ggxhzI)

[![MS Build video](https://raw.githubusercontent.com/stephlocke/lazyCDN/master/realtimepipelinevidDND.png)](https://www.youtube.com/watch?v=Ja08cPsk3ck)
 
 ## Building the pipeline
 ### Fork the repo
 1. In GitHub, fork the repository
 2. [Create a service principal and add to GitHub environment](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure)
 3. Trigger the Github action

 ### Building a logic app
 1. Edit the logic app 
 2. Validate the twitter connection

### Get connection info
Use the windows clipboard ring (win+v) to make these available to you
1. Navigate to the event hub and grab the connection string for the listener policy
2. Go to the cognitive service, and get the connection key and endpoint
### Building data streams
1. Open DataBricks workspace
2. In the [workspace](https://docs.azuredatabricks.net/user-guide/workspace.html) section for your user, import the [dbc](AIpipeline.dbc) from this repo
3. Get the tweet streaming going
     + Open AIpipeline > Tweet Schema Definition notebook
     + Update the eventhub connection string
     + Use Run All Below on top cell
4. Get the image streaming going
     + Open AIpipeline > Image Schema Definition notebook
     + Update the eventhub connection string
     + Use Run All Below on top cell

### Supplementing data with AI
1. Open DataBricks workspace
3. Get the tweet AI going
     + Open AIpipeline > Tweet Supplementing notebook
     + Update the cognitive services information
     + Use Run All Below on top cell
4. Get the image AI going
     + Open AIpipeline > Image Supplementing notebook
     + Update the cognitive services information
     + Use Run All Below on top cell
     
### Realtime presentation
1. Open PowerBI.com
2. Create `tweet` streaming dataset with `enqueuedTime`: DateTime, `overallsentiment`:text, `tweet`:text, `identifiedLanguage`:text
3. Open Power BI streaming notebook and add PBI URL into `pbi_tweet`
4. Create `image` streaming dataset with `enqueuedTime`: DateTime, `keyCategory`:text, `body`:text
5. Open Shipping to Power BI notebook and add PBI URL into `pbi_image`
6. Use Run All Below on top cell
7. Open Realtime notebook
     + Use Run All Below on top cell
     + Select Dashboard view
8. Create tiles on Power BI Dashboard

## Further reading
- https://mmlspark.blob.core.windows.net/website/index.html#install
- https://docs.databricks.com/spark/latest/structured-streaming/index.html
- https://blogs.technet.microsoft.com/uktechnet/2019/02/20/structured-streaming-with-databricks-into-power-bi-cosmos-db/
- https://docs.microsoft.com/en-us/azure/azure-databricks/databricks-stream-from-eventhubs
- https://spark.apache.org/docs/2.1.0/ml-pipeline.html
- https://azure.microsoft.com/en-gb/solutions/architecture/personalized-offers/
- https://delta.io

