#!/bin/bash
DSCLOUDDIR=$1
DSROOT=$2
CFDEPLOYMENTNAME=$3
source $DSCLOUDDIR/cf-params.sh
LOGD=$DSROOT/logs
CONF=/tmp/awslogs.conf
MAINCONF=/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent-config.json
function process_entry {
    local LOG=$1
    local LOGNAME=$(basename "${LOG%.*}")
    local ENT="{
\"file_path\": \"$LOG\",
\"log_stream_name\": \"$LOGNAME\",
\"log_group_name\": \"$CFDEPLOYMENTNAME/{instance_id}\"},"
    echo -ne ">> $LOG\n"
    echo -ne "$ENT\n" >> $CONF
}
function make_list {
    local LOGS=(`ls -t $LOGD/$1*`)
    for log in "${LOGS[@]}"
    do
        process_entry $log
    done
}
agentconf="\n 
{ \n 
\"agent\": { \n 
\"run_as_user\": \"root\"
}, \n
\"logs\": {
\"force_flush_interval\": 5,
\"logs_collected\": { 
\"files\": {
\"collect_list\": [
"                     
echo -ne "$agentconf" >> $CONF
echo -ne >> $CONF
echo -ne >> $CONF
make_list BackendLog
echo -ne >> $CONF
echo -ne >> $CONF
make_list CoreLog
echo -ne >>$CONF
make_list WebLog
echo -ne >> $CONF
sed -i '$ s/.$//' /tmp/awslogs.conf
echo -ne >> $CONF
OUTPUT="
] \n } \n } \n } \n } \n 
 "  
echo -ne "$OUTPUT" >> $CONF
mv -f $CONF $MAINCONF
chmod 755 $LOGD
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a append-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent-config.json -s