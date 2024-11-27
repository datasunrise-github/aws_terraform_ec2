#!/bin/bash
mkdir -p /opt/cooked/
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
echo '#!/bin/bash' | sudo tee /opt/cooked/cf-params.sh
echo "
INST_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id -H "X-aws-ec2-metadata-token: $TOKEN"`
CLOUD_INIT_LOG=/var/log/cloud-init-output.log
export CFSTACKNAME=\"${STACKNAME}\"
export CFDEPLOYMENTNAME=\"${DeploymentName}\"
export EC2REGION=\"${EC2REGION}\"
DSDISTURL=\"${DSDISTURL}\"
DSLICTYPE=\"${DSLICTYPE}\"
DSCLOUDDIR=\"/opt/ds-cloud\"
DSROOT=\"/opt/datasunrise\"

AWS_AMI_PCODE=\"e4d3d3b6266ocd12it8gny7gh\"
AWS_CAR_PCODE=\"88q6e9h0zcpo4hpvxrxtlglgd\"
InitialAMinSize=\"${AMinSize}\"
ASG_NAME=\"${ASG_NAME}\"
BackupS3BucketName=\"${BackupS3BucketName}\"
AWSCLIProxy=\"${AWSCLIProxy}\"
AlarmEmail=\"${AlarmEmail}\"
DSSecGroupId=\"${DSSGroupId}\"
SSHADMINCIDR=\"${AdminLocationCIDR}\"
ELBProxyEndpoint=\"${DNSName}\"
AlarmNamePrefix=\"ServiceAliveAlarm\"
AlarmName=\"\$AlarmNamePrefix-\$INST_ID\"
CWLOGUPLOAD_ENABLED=\"${CWLOGUPLOAD_ENABLED}\"
CWLOGUPLOAD_INTERVAL=\"${CWLOGUPLOAD_INTERVAL}\"
DS_SERVER=ds-\$INST_ID
DS_HOSTNAME=`curl -s http://169.254.169.254/latest/meta-data/hostname -H "X-aws-ec2-metadata-token: $TOKEN"`
DS_HOST_PRIVIP=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4 -H "X-aws-ec2-metadata-token: $TOKEN"`
AF_HOME=\$DSROOT
AF_CONFIG=\$AF_HOME

TRG_INSTNAME=\"DBInstance-${DeploymentName}\"
TRG_DBTYPE=\"${TRG_DBTYPE}\"
TRG_DBHOST=\"${TRG_DBHOST}\"
TRG_DBPORT=\"${TRG_DBPORT}\"
TRG_DBNAME=\"${TRG_DBNAME}\"
TRG_DBUSER=\"${TRG_DBUSER}\"
TRG_ENCRYPTION=\"${TRG_ENCRYPTION}\"

HA_DBTYPE=\"${HA_DBTYPE}\"
HA_DBHOST=\"${HA_DBHOST}\"
HA_DBPORT=\"${HA_DBPORT}\"
HA_DBNAME=\"${HA_DBNAME}\"
HA_DBUSER=\"${HA_DBUSER}\"

# 0 - Sqlite, 1 - PgSQL, 2 - MySQL, 3 - Redshift, 4 - Aurora
HA_AUTYPE=\"${HA_AUTYPE}\"
HA_AUHOST=\"${HA_AUHOST}\"
HA_AUPORT=\"${HA_AUPORT}\"
HA_AUNAME=\"${HA_AUNAME}\"
HA_AUUSER=\"${HA_AUUSER}\"

INST_CAPT=\"{\$INST_ID}\" " | sudo tee -a /opt/cooked/cf-params.sh
