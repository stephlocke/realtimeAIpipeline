var rg = resourceGroup().name
var location  = resourceGroup().location
var apiFragment  = '${subscription().id}/providers/Microsoft.Web/locations/${location}/managedApis/'

// storage
resource store 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: '${rg}store'
  kind: 'StorageV2'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
}
resource storeTweets 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${store.name}/default/rawtweets'
}
resource storeImages 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${store.name}/default/rawimages'
}
resource storeTweetsAI 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${store.name}/default/aitweets'
}
resource storeImagesAI 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${store.name}/default/aiimages'
}
// eventhub
resource eventhub 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: '${rg}eh'
  location: location  
}
resource ehTweets 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: '${eventhub.name}/ehTweets'
}
resource ehImages 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: '${eventhub.name}/ehImages'
}
resource ehAuth 'Microsoft.EventHub/namespaces/authorizationRules@2017-04-01' = {
  name: '${eventhub.name}/RootMAnageSharedAccessKey'
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}
// cognitive services
resource cogsvc 'Microsoft.CognitiveServices/accounts@2017-04-18' = {
  name: '${rg}cogsvc'
  location: location
  kind: 'CognitiveServices'
  sku: {
    name: 'S0'
  }
}


// logic apps connectors
resource lgBlob 'Microsoft.Web/connections@2016-06-01' = {
  name: '${rg}blob'
  location: location
  properties: {
    api: {
      id: '${apiFragment}azureblob'
    }
    parameterValues: {
      accessKey: listKeys(store.id,'2021-02-01').keys[0].value
      accountName: store.name
    }
  }
}
resource lgTwitter 'Microsoft.Web/connections@2016-06-01' = {
  name: '${rg}twitter'
  location: location
  properties: {
    api: {
      id: '${apiFragment}twitter'
    }
    customParameterValues: {
    }
  }
}
resource lgEH 'Microsoft.Web/connections@2016-06-01' = {
  name: '${rg}eventhubs'
  location: location
  properties: {
    api: {
      id: '${apiFragment}eventhubs'
    }
    parameterValues: {
      connectionString: listKeys(ehAuth.id, '2017-04-01').primaryConnectionString
    }
  }
}
resource lgCS 'Microsoft.Web/connections@2016-06-01' = {
  name: '${rg}lgCS'
  location: location
  properties: {
    api: {
      id: '${apiFragment}cognitiveservicestextanalytics'
    }
    parameterValues: {
      siteUrl: cogsvc.properties.endpoint
      apiKey: listKeys(cogsvc.id, '2017-04-18').key1
    }
  }
}

// logic app - getters
resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${rg}fetch'
  location: location
  properties: {
    state: 'Disabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      parameters: {
          '$connections': {
              type: 'Object'
          }
      }
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
              searchQuery: '#dataminds'
            }
          }
        }
        Create_CSV: {
          description: 'Flatten tweets down for simplicity'
          runAfter: {
            Search_Tweets: [
              'Succeeded'
            ]
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
            Create_CSV: [
              'Succeeded'
            ]
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
            body: '@body(\'Create_CSV\')'
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
            Store_CSV: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          foreach: '@body(\'Search_Tweets\')'
          actions: {
            Process_media_URLS: {
              description: 'Iterate through each media URL'
              runAfter: {}
              type: 'Foreach'
              foreach: '@items(\'Process_for_images\')[\'MediaUrls\']'
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
                    Fetch_Image: [
                      'Succeeded'
                    ]
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
                    body: '@body(\'Fetch_Image\')'
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
                Notify_About_Image: {
                  description: 'Publish an event containing the media URL'
                  runAfter: {
                    Store_Image: [
                      'Succeeded'
                    ]
                  }
                  type: 'ApiConnection'
                  inputs: {
                    body: {
                      ContentData: '@{base64(item())}'
                    }
                    host: {
                      connection: {
                        name: '@parameters(\'$connections\')[\'eventhub\'][\'connectionId\']'
                      }
                    }
                    method: 'post'
                    path: '/@{encodeURIComponent(\'ehimages\')}/events'
                  }
                }
              }
            }
          }
        }
        Notify_about_tweets: {
          description: 'Iterate to through tweets'
          runAfter: {
            Process_for_images: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          foreach: '@body(\'Search_Tweets\')'
          actions: {
            Post_tweet: {
              description: 'Publish an event containing the tweet JSON'
              runAfter: {}
              type: 'ApiConnection'
              inputs: {
                body: {
                  ContentData: '@{base64(item()[\'TweetText\'])}'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'eventhub\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/@{encodeURIComponent(\'ehtweets\')}/events'
              }
            }
          }
        }        
      }
    }
    parameters: {
      '$connections':{
        value:{
          azureblob : {
            connectionId: lgBlob.id
            connectionName:'store'
            id: '${apiFragment}azureblob'
          }
          twitter : {
            connectionId: lgTwitter.id
            connectionName:'twitter'
            id: '${apiFragment}twitter'
          }
          eventhub : {
            connectionId: lgEH.id
            connectionName:'eventhub'
            id: '${apiFragment}eventhubs'
          }
        } 
      }
    }
  } 
}

// Logic app - image analysis
resource ImageCV 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${rg}images'
  location: location
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      parameters: {
          '$connections': {
              type: 'Object'
          }
      }
      triggers: {
        'New image' : {
          evaluatedRecurrence: {
            frequency: 'Minute'
            interval: 1
          }
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'eventhub\'][\'connectionId\']'
              }
              event: '@{encodeURIComponent(\'ehimages\')}/events'
            }
            method: 'get'
            path: '/@{encodeURIComponent(\'ehimages\')}/events'
            queries: {
              consumerGroupName: '$Default'
              contentType: 'application/octet-stream'
              maximumEventcount: 10
            }
          }
          recurrence: {
            frequency: 'Minute'
            interval: 1
          }
          splitOn: '@triggerBody()'
          type: 'ApiConnection'
        }
      }
      actions: {
        'Analyse image': {
          inputs: {
            body: {
              url: '@base64ToString(@triggerBody()[\'ContentData\'])'
            }
            host:{
              connection: {
                name: '@parameters(\'$connections\')[\'cogsvcs\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v3/subdomain/@{encodeURIComponent(encodeURIComponent(\'autoFilledSubdomain\'))}/vision/v2.0/analyze'
            queries: {
              format: 'Image URL'
              visualFeatures: 'Tags,Description,Categories'
            }
          }
          runAfter: {}
          type: 'ApiConnection'
        }
        'Push to blob': {
          inputs: {
            body: '@body(\'Analyse image\')'
            headers: {
              ReadFileMetadataFromServer: true
            }
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'azureblob\'][\'connectionId\']'
              }
            }
            method: 'post'
            path: '/v2/datasets/@{encodeURIComponent(encodeURIComponent(\'AccountNameFromSettings\'))}/files'
            queries: {
              folderPath: 'aiimages'
              name: '@base64ToString(@triggerBody()[\'ContentData\'])'
              queryParametersSingleEncoded: true
            }
          }
          runAfter: {
            'Analyse image': [
              'Succeeded'
            ]
          }
          runtimeConfiguration: {
            contentTransfer: {
              transferMode: 'Chunked'
            }
          }
          type: 'ApiConnection'
        }
      }


    }
    parameters: {
      '$connections':{
        value:{
          azureblob : {
            connectionId: lgBlob.id
            connectionName:'store'
            id: '${apiFragment}azureblob'
          }
          eventhub : {
            connectionId: lgEH.id
            connectionName:'eventhub'
            id: '${apiFragment}eventhubs'
          }
          computervision : {
            connectionId: lgCS.id
            connectionName:'cogsvcs'
            id: '${apiFragment}cogsvcs'
          }
        } 
      }
    } 
  }
}
