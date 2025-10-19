const {DataformClient} = require('@google-cloud/dataform').v1;
const dataformClient = new DataformClient();

exports.runDataform = async (event) => {

  //The env variables are to be defined by terraform apply or terraform.tfvars
  const projectId = process.env.PROJECT;
  const parent = 'projects/'+projectId+'/locations/'+process.env.LOCATION+'/repositories/'+process.env.REPO;
  const workspaceId = parent + '/workspaces/'+process.env.WORKSPACE;

  const eventData = JSON.parse(Buffer.from(event.body.message.data, 'base64').toString());
  const destinationTableId = eventData.protoPayload.serviceData.jobCompletedEvent.job.jobConfiguration.load.destinationTable.tableId;

  const Date_Format = (date) => {
    const t = new Date(date)
    const y = t.getFullYear()
    const m = ('0' + (t.getMonth() + 1)).slice(-2)
    const d = ('0' + t.getDate()).slice(-2)
    return `${y}${m}${d}`
  };
  const d = new Date();
  const today = d.setTime(d.getTime() - 0 * 24 * 60 * 60 * 1000);

  const compilationResult = {
    name: "dataform_ga4_compil_" + Date_Format(today) + "_" + destinationTableId.replace('events_', ''),
    codeCompilationConfig: {
      "vars": {
          //Exporting the updated GA4 raw data "table_date" info, that can be used in Dataform
          "GA4_TABLE": destinationTableId
        }
    },
    workspace: workspaceId
  };
  
  const request = {
      parent,
      compilationResult
  };
  const response = await dataformClient.createCompilationResult(request)
  
  const request2 = {
      parent,
      workflowInvocation: {
        name: "dataform_ga4_invoke_" + Date_Format(today) + "_" + destinationTableId.replace('events_', ''),
        invocationConfig: {
          //includedTags: ["tag1","tag2"],
          fullyRefreshIncrementalTablesEnabled: false,
          transitiveDependenciesIncluded: true,
          transitiveDependentsIncluded: false
        },
        compilationResult: response[0].name
      }
  };

  const response2 = await dataformClient.createWorkflowInvocation(request2)
  return response2;

};
