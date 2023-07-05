#!/bin/bash
uploadSetupLogs() {
    if [ ! -z "$BackupS3BucketName" ]; then
        aws s3 cp $CLOUD_INIT_LOG s3://$BackupS3BucketName/Deploying/$INST_ID/
    fi
}
uploadAllSetupLogs() {
    uploadSetupLogs
    if [ ! -z "$BackupS3BucketName" ]; then
        aws s3 sync $DSROOT/logs s3://$BackupS3BucketName/Deploying/$INST_ID/
    fi
}
setupCWLogUploading() {
    if [ "$CWLOGUPLOAD_ENABLED" == "ON" ]; then
		echo "Setup CloudWatch Logs synchronization..." >> $PREP_LOG
        echo -ne "*/$CWLOGUPLOAD_INTERVAL * * * * root $DSCLOUDDIR/push-cwlogs-conf.sh $DSCLOUDDIR $DSROOT $CFDEPLOYMENTNAME \n" | tee --append /etc/crontab
        rm -fr /root/.aws
        echo "Setup CloudWatch Logs synchronization DONE" >> $PREP_LOG
    fi
}
stsDecodeMessage() {
    aws sts decode-authorization-message --encoded-message "$1"
}
stsDecodeMessageJSon() {
    local jtmp=`stsDecodeMessage $1 | python3 -c "import sys, json; jnp=json.load(sys.stdin)['DecodedMessage']; print(jnp)"`
    echo "$jtmp" | python3 -c "import sys, json; jnp=json.load(sys.stdin); print(json.dumps(jnp, indent=4))"
}
