This script will detect update failiures in windows machines and do the most common troubleshooting for you before creating a local error log as a .csv.

we clear our "C:\Windows\SoftwareDistribution" and "C:\Windows\System32\catroot2" files by renaming them .old's

after that we do an SFC /ScanNow and a DISM online /cleanup-image /scanhealth and a /online /cleanup-image /restorehealth

Finally we have it do a windows update scan to queue up updates WITHOUT initiating a reboot, these updates will hit after the next reboot instead. 

All logging is done locally but you can go ahead and tweak this script to have it send everything back to an endpoint on azure.
