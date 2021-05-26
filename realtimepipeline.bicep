var rg = resourceGroup().name
var location  = resourceGroup().location
var apiFragment  = concat(subscription().id, '/providers/Microsoft.Web/locations/',location,'/managedApis/')
var managedResourceGroupName  = 'databricks-rg-db-${uniqueString(rg, resourceGroup().id)}'
// storage
resource store 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: concat(rg, 'store')
  kind: 'StorageV2'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
}
resource storeTweets 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: concat(store.name,'/default/tweets')
}
resource storeImages 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: concat(store.name,'/default/images')
}

// cognitive services
resource cogsvc 'Microsoft.CognitiveServices/accounts@2017-04-18' = {
  name: concat(rg, 'cogsvc')
  location: location
  kind: 'CognitiveServices'
  sku: {
    name: 'S0'
  }
}

// databricks
resource databricks 'Microsoft.Databricks/workspaces@2018-04-01' = {
  name: concat(rg, 'databricks')
  location: location
  properties: {
    managedResourceGroupId: managedResourceGroupName
  }
}

// logic apps
resource lgBlob 'Microsoft.Web/connections@2016-06-01' = {
  name: concat(rg, 'blob')
  location: location
  properties: {
    api: {
      id: concat(apiFragment, 'azureblob')
    }
    parameterValues: {
      accessKey: listKeys(store.id,'2021-02-01')[1]
      accountName: store.name
    }
  }
}
resource lgTwitter 'Microsoft.Web/connections@2016-06-01' = {
  name: concat(rg, 'twitter')
  location: location
  properties: {
    customParameterValues: {
      api: {
        id: concat(apiFragment, 'twitter')
      }
    }
  }
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: concat(rg, 'logic')
  location: location
  properties: {
    state: 'Enabled'
    parameters: {
      connections:{
        value:{
          azureblob : {
            connectionId: lgBlob.id
            connectionName:'store'
            id: concat(apiFragment, 'azureblob')
          }
          twitter : {
            connectionId: lgTwitter.id
            connectionName:'twitter'
            id: concat(apiFragment, 'twitter')
          }
        } 
      }
    }
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      triggers:  {
        recurrence: {
          type: 'recurrence'
          recurrence: {
            frequency: 'Minute'
            interval: 1
          }
        }
      }
      actions: {
        Search_Tweets: {
          description: 'This performs a poll of tweets'
          runAfter: {}
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'twitter\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/searchtweets'
            queries: {
              maxResults: 50
              searchQuery: '#dataceili'
            }
          }
        }
        Create_CSV: {
          description: 'Flatten tweets down for simplicity'
          runAfter: {
            Search_Tweets: ['Succeeded']
          }
          type: 'Table'
          inputs: {
            format: 'CSV'
            from: '@body(\'Search_Tweets\')'
          }
        }
        Store_CSV: {
          description: 'Ship the CSV to blob store - mimics new data arriving near real-time'
          runAfter: {
            Create_CSV: ['Succeeded']
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/datasets/default/files'
            queries: {
              folderPath: 'tweets'
              name: '@{concat(utcNow(),\'.csv\')}'
              queryParametersSingleEncoded: true
            }
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
        }
        Process_for_images: {
          description: 'Iterate to find tweets with images to store'
          runAfter: {
            Store_CSV: ['Succeeded']
          }
          type: 'Foreach'
          foreach: '@body(\'Search_Tweets\')'
          actions: {
            Process_media_URLS: {
              description: 'Iterate through each media URL'
              runAfter: {}
              type: 'Foreach'
              foreach: '@body(\'Search_Tweets\')'
              actions: {
                Fetch_Image: {
                  description: 'HTTP GET call to retrieve media'
                  runAfter: {}
                  type: 'Http'
                  inputs: {
                    method: 'Get'
                    uri: '@{item()}'
                  }
                }
                Store_Image: {
                  description: 'Ship the CSV to blob store - mimics new data arriving near real-time'
                  runAfter: {
                    Fetch_Image: ['Succeeded']
                  }
                  type: 'ApiConnection'
                  inputs: {
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    path: '/datasets/default/files'
                    queries: {
                      folderPath: 'images'
                      name: '@{uriPath(item())}'
                      queryParametersSingleEncoded: true
                    }
                  }
                  runtimeConfiguration: {
                    contentTransfer: {
                      transferMode: 'Chunked'
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}


output dbId string = databricks.id
