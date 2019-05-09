# Coding from scratch a realtime Azure data and AI pipeline
In just 60 minutes, this session will demonstrate an end to end data pipeline supplemented by AI to achieve insights real-time. Using components like Azure Functions, Event Hubs, Databricks, Cognitive Services, and Power BI I'll be putting together a pipeline that takes our #msBuild social stream and analyses it realtime. Join me as I show how quickly these sorts of systems can be put together for awesome insight. 

- [MS Build talk entry](https://mybuild.techcommunity.microsoft.com/sessions/77150)
- Prerecorded demo vids: [The Azure Side](https://www.youtube.com/watch?v=0mh9qIyp4SU), [The AI side](https://youtu.be/1XhdKjBXoxM)
 
 ## Building the pipeline
 ### Provisioning resources
 1. Open the Cloud Shell in Bash mode
 2. Adjust the variables in [build.azcli](build.azcli) to suit your needs
 3. Copy the file contents and use Shift + Insert to paste them into the cloud shell
 4. Once finished, navigate to DataBricks resouce and open the workspace
 5. Get a [PAT](https://docs.azuredatabricks.net/api/latest/authentication.html#token-management)
 6. Run the first part of [databrickscluster.sh](databrickscluster.sh) i.e. up to and including `databricks configure`
 7. Enter the url and PAT
 8. Run the create cluster code and copy the cluster id to the end of the final two lines of databricks code
 9. Run these final lines of code
 
 ### Building a logic app
 1. Open the logic app and remove the current contents
 2. Add a New Tweet trigger and insert your query
 3. Add a Control IF action to filter out retweets
     + Put OriginalTweet in condition, select equal to for comparison type, and then use the expression editor and search for null
 4. In the True block, add an Eventhub action
 5. Connect the action to one of your event hubs 
     + Add the Content parameter and use an expression of `base64(triggerBody())`
 7. Connect a Foreach action and use Media URLs
 8. Inside the for each add a HTTP task
    + Configure the HTTP task with GET and insert the `Current Item` (in code view = `@{items('For_each')}`) into the URL
 10. Add a Create Blob task after the HTTP task and connect it to your storage account
    + Set container to `images`, the blob name to custom expression `uriPath(Current Item)` (in code view = `@{items('For_each')}`), the contents to HTTP body
 
### Resizing images
1. Use Azure Deploy option on [LD fork](https://github.com/lockedata/fl-image-resize) or [original](https://github.com/jefking/fl-image-resize) of resizing function
2. Go through configuration and deploy
3. Either in the deployment or the application settings, set dimensions to 1920 x 1080 and ensure the original storage account is being monitored for images
 
### Creating an image feed
1. Select events in the menu panel for the storage account
2. Create a subscription with the event hub sink
3. Add the *other* event hub as the sink
4. Apply a filter to subject of `/blobServices/default/containers/thumbnails`
5. Deselect deletion activities from monitored events
 
### Building data streams
1. Open DataBricks workspace
2. In the [workspace](https://docs.azuredatabricks.net/user-guide/workspace.html) section for your user, import the [dbc](https://github.com/lockedata/realtimeAIpipeline/raw/master/AIpipeline.dbc) from this repo
3. Get the tweet streaming going
     + Open AIpipeline > Tweet Schema Definition notebook
     + Update the eventhub connection string with the eventhub being used by the logic app
     + Use Run All Below on top cell
4. Get the image streaming going
     + Open AIpipeline > Image Schema Definition notebook
     + Update the eventhub connection string with the eventhub being used by the event grid
     + Use Run All Below on top cell

### Supplementing data with AI
1. Open DataBricks workspace
3. Get the tweet AI going
     + Open AIpipeline > Tweet Supplementing notebook
     + Update the cognitive services key with your key
     + Adjust any endpoint URLs if required
     + Use Run All Below on top cell
4. Get the image AI going
     + Open AIpipeline > Image Supplementing notebook
     + Update the cognitive services key with your key
     + Adjust any endpoint URLs if required
     + Use Run All Below on top cell
     
### Realtime presentation
1. Open PowerBI.com
2. Create `tweet` streaming dataset with `enqueuedTime`: DateTime, `sentimentScore`:number, `tweet`:text, `identifiedLanguage`:text
3. Open Power BI streaming notebook and add PBI URL into `pbi_tweet`
4. Create `image` streaming dataset with `enqueuedTime`: DateTime, `keyCategory`:text, `url`:text
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

