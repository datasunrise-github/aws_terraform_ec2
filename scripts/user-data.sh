#!/bin/bash

export PREP_LOG=/var/log/cloud-init-output.log
echo "Configuration script has been started" >> $PREP_LOG
sudo yum update -y -q
yum install -y wget ipcalc
pip3 install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-py3-latest.tar.gz
shopt -s extglob
export CFS_BGN_TS=$(date +%s.%N)

export AMIProductCode=e4d3d3b6266ocd12it8gny7gh
export CARProductCode=88q6e9h0zcpo4hpvxrxtlglgd
export DSCloudWatchEventSource=DataSunrise
export DSRoot=/opt/datasunrise
export DSCLOUDDIR=/opt/ds-cloud
export BackupUploadLog=/tmp/backup-upload.log
export BackupTempDir=/tmp/ds-backups
export AliveMetricName=ServiceAlive
export AliveMetricNamespace=DataSunrise
export AliveMetricLog=/tmp/send-alive.log

source /opt/cooked/cf-params.sh

mkdir -p $DSCLOUDDIR

mv /opt/cooked/* $DSCLOUDDIR/
rm -fR /opt/cooked

echo "DSAdminPassword exporting has been started"  >> $PREP_LOG
export DSAdminPassword=`aws --region $EC2REGION secretsmanager get-secret-value --secret-id $CFDEPLOYMENTNAME-secret-admin-password --query SecretString --output text`

cd $DSCLOUDDIR
# DO NOT change order!
echo "vm-creds execution" >> $PREP_LOG	
source vm-creds.sh
echo "cf-params execution"  >> $PREP_LOG
source cf-params.sh
echo "ds-manip execution"  >> $PREP_LOG
source ds-manip.sh
echo "ds-setup execution"  >> $PREP_LOG
source ds-setup.sh
echo "aws-ds-setup execution"  >> $PREP_LOG
source aws-ds-setup.sh
echo "pre-setup execution"  >> $PREP_LOG
source pre-setup.sh

if [ ! -z "$AlarmEmail" ]; then                
	AlarmSNSTopic=`aws sns create-topic --name $CFDEPLOYMENTNAME-DataSunrise-ServiceDown`
	AlarmSNSTopic=`echo $AlarmSNSTopic | sed -r 's/\{ "TopicArn": "(.*)" \}/\1/g'`
	aws sns subscribe --topic-arn "$AlarmSNSTopic" --protocol email --notification-endpoint "$AlarmEmail"
fi
echo "Setting up Cloud Watch Alarm"  >> $PREP_LOG
setupCloudWatch() {
    if [ ! -z "$AlarmEmail" ]; then
        echo "Setup service monitoring and alarm..." >> $PREP_LOG
        aws cloudwatch put-metric-alarm --alarm-name "$AlarmName" --alarm-description "DataSunrise service alive alarm" --metric-name "$AliveMetricName" --namespace "$AliveMetricNamespace" --statistic Average --period 60 --threshold 1 --comparison-operator LessThanThreshold --dimensions "Name=InstanceId,Value=$INST_ID" --evaluation-periods 3 --alarm-actions "$AlarmSNSTopic"
        RETVAL=$?
        if [ $RETVAL -eq 0 ]; then
            echo -ne "*/1 * * * * root $DSCLOUDDIR/service-mon.sh\\n" | sudo tee --append /etc/crontab
        fi
        echo "Setup service monitoring and alarm result - $RETVAL" >> $PREP_LOG
    fi
}

if [ -z "$HA_DBHOST" ] || [ -z "$HA_DBPORT" ]; then
    echo "Dictionary RDS not found! Goodbye..." >> $PREP_LOG
    onAbortSetup
    exit $RETVAL
fi
if [ -z "$HA_AUHOST" ] || [ -z "$HA_AUPORT" ]; then
    echo "Audit RDS not found! Goodbye..." >> $PREP_LOG
    onAbortSetup
    exit $RETVAL
fi

installProduct
if [ "$RETVAL" != "0" ]; then
    echo "Installation Error! Goodbye..." >> $PREP_LOG
    onAbortSetup
    exit $RETVAL
fi
# Installation OK, continue
makeItMine

echo "Setup DataSunrise..." >> $PREP_LOG
cd $DSROOT

FIRST_NODE=0
resetDict
setDictionaryLicense
if [ "$RETVAL" == "93" ]; then
    FIRST_NODE=1
    echo "Setup First Node of DataSunrise..." >> $PREP_LOG    
    resetAdminPassword
    
elif [ "$RETVAL" == "94" ]; then
    FIRST_NODE=0
    echo "Setup Next Node of DataSunrise..." >> $PREP_LOG
else
    echo "Setup Dictionary Error! Goodbye..." >> $PREP_LOG
    onAbortSetup
    exit $RETVAL
fi
resetAudit
if [ "$RETVAL" != "96" ]; then
    echo "Setup Audit Error! Goodbye..." >> $PREP_LOG
    onAbortSetup
    exit $RETVAL
fi
makeItMine
cleanLogs
service datasunrise start
sleep 20
if [ "$FIRST_NODE" == "1" ]; then
  setupProxy
  setupCleaningTask
else
  processSetupOrCopy
  runCleaningTask
fi
if [ "$FIRST_NODE" == "1" ]; then
    if [ ! -z "$BackupS3BucketName" ]; then
      setupBackupParams
    fi
    setupAdditionals
fi
setupBackupActions

service datasunrise stop
cleanLogs
makeItMine
configureKeepAlive
configureJVM
setcapAppFirewallCore
service datasunrise start

CFS_END_TS=$(date +%s.%N)
CFS_ELLAPSED=$(echo "$CFS_END_TS - $CFS_BGN_TS" | bc)
echo "Setup DataSunrise finished in $CFS_ELLAPSED sec."

uploadSetupLogs
setupCWLogUploading
fixfiles -FB onboot
sed -i 's/tmpfs \/dev\/shm tmpfs defaults,nodev,nosuid 0/tmpfs \/dev\/shm tmpfs defaults,nodev,nosuid,noexec 0/g' /etc/fstab
reboot
