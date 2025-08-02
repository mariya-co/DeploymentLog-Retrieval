# DeploymentLog-Retrieval
Log retrieval script which grabs logs related to windows update and MCM application/windows deployments.

This script grabs the following logs:
cbs.log
ccmrepair.log
ccmsetup.log
client.msi.log
updatesdeployment.log
updateshandler.log
wuahandler.log

As well as running a Get-Windowsupdatelog on the machine and copies this and the other logs to your local machine.

The script will also then create filtered versions of these logs that contains only errors and warnings to narrow down any issues that maybe within the log files.
