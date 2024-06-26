#!/bin/bash
resetAdminPassword() {
    echo "Reset Admin Password..." >> $PREP_LOG
    LD_LIBRARY_PATH="$DSROOT":"$DSROOT/lib":$LD_LIBRARY_PATH AF_HOME="$AF_HOME" AF_CONFIG="$AF_HOME" $DSROOT/AppBackendService SET_ADMIN_PASSWORD=$DSAdminPassword
    RETVAL=$?
    echo $INST_CAPT: Reset DS Admin Password result - $RETVAL
}

resetDict() {
    local HA_DBTYPE_LWR="`echo "$HA_DBTYPE" | tr '[:upper:]' '[:lower:]'`"
    local HA_DBPASSWD="`aws --region $EC2REGION secretsmanager get-secret-value --secret-id $CFDEPLOYMENTNAME-secret-config-password --query SecretString --output text`"
    echo "Reset Dictionary..." >> $PREP_LOG
    LD_LIBRARY_PATH="$DSROOT":"$DSROOT/lib":$LD_LIBRARY_PATH AF_HOME="$AF_HOME" AF_CONFIG="$AF_HOME" $DSROOT/AppBackendService CLEAN_LOCAL_SETTINGS PRINT_PROGRESS REMOVE_SERVER_BY_HOST_PORT=1 DICTIONARY_TYPE="$HA_DBTYPE_LWR" DICTIONARY_HOST="$HA_DBHOST" DICTIONARY_PORT="$HA_DBPORT" DICTIONARY_DB_NAME="$HA_DBNAME" DICTIONARY_LOGIN="$HA_DBUSER" DICTIONARY_PASS="$HA_DBPASSWD" FIREWALL_SERVER_NAME="$DS_SERVER" FIREWALL_SERVER_HOST="$DS_HOST_PRIVIP" FIREWALL_SERVER_BACKEND_PORT=11000 FIREWALL_SERVER_CORE_PORT=11001 FIREWALL_SERVER_BACKEND_HTTPS=1 FIREWALL_SERVER_CORE_HTTPS=1
    RETVAL=$?
    echo "Reset DS Dictionary to $HA_DBHOST:$HA_DBPORT result - $RETVAL" >> $PREP_LOG
}
resetAudit() {
    local HA_AUPASSWD="`aws --region $EC2REGION secretsmanager get-secret-value --secret-id $CFDEPLOYMENTNAME-secret-config-password --query SecretString --output text`"
    echo "Reset Audit..." >> $PREP_LOG
    LD_LIBRARY_PATH="$DSROOT":"$DSROOT/lib":$LD_LIBRARY_PATH AF_HOME="$AF_HOME" AF_CONFIG="$AF_HOME" $DSROOT/AppBackendService CHANGE_SETTINGS AuditDatabaseType="$HA_AUTYPE" AuditDatabaseHost="$HA_AUHOST" AuditDatabasePort="$HA_AUPORT" AuditDatabaseName="$HA_AUNAME" AuditLogin="$HA_AUUSER" AuditPassword="$HA_AUPASSWD"
    RETVAL=$?
    echo "Reset DS Audit to $HA_AUHOST:$HA_AUPORT result - $RETVAL" >> $PREP_LOG
}
setupProxy() {
    local TRG_DBPASSWD="`aws --region $EC2REGION secretsmanager get-secret-value --secret-id $CFDEPLOYMENTNAME-secret-tdb-password --query SecretString --output text`"
    echo "Setup proxy..." >> $PREP_LOG
    loginAsAdmin
    if [ $RETVAL == 0 ]; then
        local XTRA_ARGS=
        if [ "$TRG_DBTYPE" = "Oracle" ]; then
            XTRA_ARGS="-instance $TRG_DBNAME"
        fi
        echo "addInstancePlus $TRG_INSTNAME..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh addInstancePlus -name "$TRG_INSTNAME" $XTRA_ARGS -dbType "$TRG_DBTYPE" -dbHost "$TRG_DBHOST" -dbPort "$TRG_DBPORT" -database "$TRG_DBNAME" -login "$TRG_DBUSER" -password "$TRG_DBPASSWD" -proxyHost "$DS_HOST_PRIVIP" -proxyPort "$TRG_DBPORT" -savePassword ds -verifyCA true
        RETVAL=$?
        if [ $RETVAL == 0 ]; then
            echo "Add AuditRuleAdmin..." >> $PREP_LOG
            $DSROOT/cmdline/executecommand.sh addRule -action audit -name AuditRuleAdmin -logData true -filterType ddl -ddlSelectAll true -dbType "$TRG_DBTYPE" -instance "$TRG_INSTNAME"
            echo "Add AuditRuleDML..." >> $PREP_LOG
            $DSROOT/cmdline/executecommand.sh addRule -action audit -name AuditRuleDML -logData true -dbType "$TRG_DBTYPE" -instance "$TRG_INSTNAME"
            RETVAL=$?
        fi
    fi
    RETVAL=$?
    echo "Setup DS proxy $TRG_INSTNAME for $TDBHost:$TDBPort result - $RETVAL" >> $PREP_LOG
}
copyProxy()
{
  echo "Starting copying proxies..." >> $PREP_LOG
  service datasunrise stop
  LD_LIBRARY_PATH="$DSROOT":"$DSROOT/lib":$LD_LIBRARY_PATH AF_HOME="$AF_HOME" AF_CONFIG="$AF_HOME" $DSROOT/AppBackendService COPY_PROXIES
  LD_LIBRARY_PATH="$DSROOT":"$DSROOT/lib":$LD_LIBRARY_PATH AF_HOME="$AF_HOME" AF_CONFIG="$AF_HOME" $DSROOT/AppBackendService COPY_TRAILINGS
  service datasunrise start
  echo "Finished copying proxies" >> $PREP_LOG
}
checkInstanceExists() {
  echo "Checking existing instances..." >> $PREP_LOG
  loginAsAdmin
  local instances=`$DSROOT/cmdline/executecommand.sh showInstances`;
    if [[ "$instances" == "No Instances" ]]; then
      echo "No instances found, returning 0." >> $PREP_LOG
      return 0
    else
      echo "Instances found, returning 1." >> $PREP_LOG
      return 1
    fi
}
checkNeighbours()
{
  echo "Checking neigbour instances from my ASG..." >> $PREP_LOG
  TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
  INST_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id -H "X-aws-ec2-metadata-token: $TOKEN"`
  local neighbours=$(aws ec2 describe-instances --filters Name=tag:aws:autoscaling:groupName,Values=${ASG_NAME} | python3 -c "import sys,json; [sys.stdout.write(str(inst)) for instance in json.load(sys.stdin)['Reservations'] for inst in instance['Instances'] if inst['InstanceId'] != '$INST_ID']")
  if [[ -z $neighbours ]]; then
    echo "No neighbours found, returning 0" >> $PREP_LOG
    return 0
  else
    echo "Neighbours found, returning 1" >> $PREP_LOG
    return 1
  fi
}
waitForRandTime()
{
  echo "Waiting for random time..." >> $PREP_LOG
  sleep $(( RANDOM % 270 + 30 ));
  echo "Finished waiting" >> $PREP_LOG
}
processSetupOrCopy()
{
  echo "Entered main setupProxy function. Will decide to create or to copy..." >> $PREP_LOG
  checkInstanceExists
  if [ $? == 1 ]; then
    copyProxy
  else
    checkNeighbours
    if [ $? == 0 ]; then
      setupProxy
    else
      waitForRandTime
      checkInstanceExists
      if [ $? == 1 ]; then
        copyProxy
      else
        setupProxy
        if [ $? -ne 0 ]; then
          copyProxy
        fi
      fi
    fi
  fi
  echo "Exited main setupProxy function." >> $PREP_LOG
}
setupBackupParams() {
    echo "Setup backups..." >> $PREP_LOG
    loginAsAdmin
    if [ $RETVAL == 0 ]; then
        echo "Setup OnDictionaryBackupDoneCommand..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name OnDictionaryBackupDoneCommand -value "$DSCLOUDDIR/backup-prepare.sh <backup_path> $BackupTempDir Dictionary"
        echo "Setup OnOldLogDeleteCommand..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name OnOldLogDeleteCommand -value "$DSCLOUDDIR/backup-prepare.sh <log_file> $BackupTempDir"
        RETVAL=$?        
    fi
    echo "Setup backups result - $RETVAL" >> $PREP_LOG
}
setupBackupActions() {
    echo -ne "*/5 * * * * root $DSCLOUDDIR/backup-upload.sh s3://$BackupS3BucketName $DSCLOUDDIR $BackupTempDir $AWSCLIProxy\n" | tee --append /etc/crontab
}
setupAdditionals() {
    echo "Setup additional parameters..." >> $PREP_LOG
    loginAsAdmin
    if [ $RETVAL == 0 ]; then
        echo "Setup WebLoadBalancerEnabled..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name WebLoadBalancerEnabled -value 1
        echo "Setup AuditDiscFreeSpaceLimit for HA config..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name AuditDiscFreeSpaceLimit -value 2048
        echo "Setup LogsDiscFreeSpaceLimit for HA config..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name LogsDiscFreeSpaceLimit -value 2048
		echo "Setup EnableAWSMetrics for HA config..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name EnableAWSMetrics -value 1
        echo "Setup LogTotalSizeCore for HA config..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name LogTotalSizeCore -value 10000
        echo "Setup LogTotalSizeBackend for HA config..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name LogTotalSizeBackend -value 10000
		echo "Setup AuditPartitionEnable for HA config..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name AuditPartitionEnable -value 1
        echo "Setup AuditPartitionInterval for HA config..." >> $PREP_LOG
        $DSROOT/cmdline/executecommand.sh changeParameter -name AuditPartitionInterval -value 1
        RETVAL=$?
    fi
    echo "Setup additional parameters result - $RETVAL" >> $PREP_LOG
}
setupDSLicense() {
    echo "Setup license..." >> $PREP_LOG
    local DSLicenseKey="`aws --region $EC2REGION secretsmanager get-secret-value --secret-id $CFDEPLOYMENTNAME-secret-license-key --query SecretString --output text`"
    if [ -z "$DSLicenseKey" ]; then
        RETVAL=2
		echo "License key is EMPTY!" >> $PREP_LOG
        return $RETVAL
    fi
    echo "$DSLicenseKey" > /tmp/appfirewall.reg
    mv /tmp/appfirewall.reg $DSROOT/
    makeItMineParam $DSROOT/appfirewall.pem
    echo "Setup license result - $?" >> $PREP_LOG
}
onAbortSetup() {
    uploadAllSetupLogs
    makeItMine
    cleanLogs
    service datasunrise stop
}             
setupCleaningTask() {
    echo "Set node cleaning task..." >> $PREP_LOG
    loginAsAdmin
    if [ $RETVAL == 0 ]; then
        local CLEANING_PT_JSON="{\"id\":-1,\"storePeriodType\":0,\"storePeriodValue\":0,\"name\":\"aws_remove_servers\",\"type\":18,\"lastExecTime\":\"\",\"nextExecTime\":\"\",\"lastSuccessTime\":\"\",\"lastErrorTime\":\"\",\"serverID\":0,\"forceUpdate\":false,\"params\":{},\"frequency\":{\"minutes\":{\"beginDate\":\"2018-09-28 00:00:00\",\"repeatEvery\":10}},\"updateNextExecTime\":true}"
        $DSROOT/cmdline/executecommand.sh arbitrary -function updatePeriodicTask -jsonContent "$CLEANING_PT_JSON"
        RETVAL=$?
    fi
    echo "Set node cleaning task - $RETVAL" >> $PREP_LOG
}
runCleaningTask() {
    echo "Run node cleaning task..." >> $PREP_LOG
    loginAsAdmin
    if [ $RETVAL == 0 ]; then
        local EC2_CLEANING_TASK_ID=`$DSROOT/cmdline/executecommand.sh arbitrary -function getPeriodicTaskList -jsonContent "{taskTypes:[18]}" | python3 -c "import sys, json; print(json.load(sys.stdin)['data'][1][0])"`
        $DSROOT/cmdline/executecommand.sh arbitrary -function executePeriodicTaskManually -jsonContent "{id:$EC2_CLEANING_TASK_ID}"
        RETVAL=$?
    fi
    echo "Run node cleaning task - $RETVAL" >> $PREP_LOG
} 
configureKeepAlive() {
    echo "net.ipv4.tcp_keepalive_time = 60" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_keepalive_intvl = 10" | tee -a /etc/sysctl.conf
    echo "net.ipv4.tcp_keepalive_probes = 6" | tee -a /etc/sysctl.conf
    sysctl -p
}
createRDSKeyGroup() {
    echo "Preparing RDS SSLKeyGroup..." >> $PREP_LOG
    loginAsAdmin
    $DSROOT/cmdline/executecommand.sh addSslKeyGroup -ca $DSROOT/rds-combined-ca-bundle.pem -name RDSGroup
    echo "RDS SSLKeyGroup created." >> $PREP_LOG
}
configureJVM() {
    echo "Configuring JVM..." >> $PREP_LOG
    jvmpath=`find /usr/ -name libjvm.so`
    echo $jvmpath | tr " " "\n" | sed -e "s/libjvm.so//" > /etc/ld.so.conf.d/jvm.conf
    ldconfig
    echo "Configuring JVM result - $RETVAL" >> $PREP_LOG
}
setcapAppFirewallCore() {
    echo "Executing setcap as required" >> $PREP_LOG
    DS_VER=$($DSROOT/AppBackendService VERSION)
    DS_VER_MAJ=${!DS_VER:0:1}
    DS_VER_MIN=${!DS_VER:2:1}
    if [ $DS_VER_MAJ -ge 9 ]; then
        echo "No setcap required for $DS_VER" >> $PREP_LOG
    elif [ $DS_VER_MAJ -eq 8 ] && [ $DS_VER_MIN -ge 1 ]; then
        echo "No setcap required for $DS_VER" >> $PREP_LOG
    else
        echo "Checking specific applications for setcap requirements" >> $PREP_LOG
        if [[ -x "$DSROOT/AppFirewallCore_Sniffer" ]]; then
            echo "Setting cap_net_raw and cap_net_admin for AppFirewallCore_Sniffer" >> $PREP_LOG
            setcap 'cap_net_raw,cap_net_admin=eip' $DSROOT/AppFirewallCore_Sniffer
        fi
        
        if [[ -x "$DSROOT/PortBinder" ]]; then
            echo "Setting cap_net_bind_service for PortBinder" >> $PREP_LOG
            setcap 'cap_net_bind_service=ep' $DSROOT/PortBinder
        fi
        
        if [[ -x "$DSROOT/FreePortChecker" ]]; then
            echo "Setting cap_net_bind_service for FreePortChecker" >> $PREP_LOG
            setcap 'cap_net_bind_service=ep' $DSROOT/FreePortChecker
        fi
    fi
    echo "Execution finished. Exit code is - $?" >> $PREP_LOG
}
setDictionaryLicense()
{
    dsversion=`$DSROOT/AppBackendService VERSION`
    if [ '6.3.1.99999' = "`echo -e "6.3.1.99999\n$dsversion" | sort -V | head -n1`" ] ; then
      echo "DS Version is higher than 6.3.1.99999: $dsversion, setting license to dictionary..." >> $PREP_LOG
      LD_LIBRARY_PATH="$DSROOT":"$DSROOT/lib":$LD_LIBRARY_PATH AF_HOME="$AF_HOME" AF_CONFIG="$AF_HOME" $DSROOT/AppBackendService IMPORT_LICENSE_FROM_FILE=$DSROOT/appfirewall.reg
      echo "License has been set with exit code $?" >> $PREP_LOG
    fi
}
