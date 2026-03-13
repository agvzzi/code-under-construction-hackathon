using './main.bicep'

param location = 'norwayeast'

param environment = 'dev'

param workload = 'todo'

// Object ID of the signed-in user for SQL Server Entra admin
param sqlAdminObjectId = 'bdc1bf70-c3ff-4936-bfe8-01f2e6c9d0f2'

param sqlAdminLoginName = 'sqladmin-entra'

param tags = {
  environment: 'dev'
  workload: 'todo'
  owner: 'hackathon-team'
  costCenter: 'hackathon-2026'
  'hackathon-team': 'hackteam'
}
