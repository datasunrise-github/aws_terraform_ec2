#!/bin/bash
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTID=`curl -s http://169.254.169.254/latest/meta-data/instance-id -H "X-aws-ec2-metadata-token: $TOKEN"`
IAM_ROLE=`curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/ -H "X-aws-ec2-metadata-token: $TOKEN"`
if [ -z "$IAM_ROLE" ]; then
    echo "$INSTID: Security credentials for this instance is not found!"
else
    IAM_NOT_FOUND=`echo "$IAM_ROLE" | grep -i "not found"`
    if [ -z "$IAM_NOT_FOUND" ]; then
        IAM_CREDS=`curl -s "http://169.254.169.254/latest/meta-data/iam/security-credentials/$IAM_ROLE" -H "X-aws-ec2-metadata-token: $TOKEN"`
        export AWS_ACCESS_KEY_ID=`echo $IAM_CREDS | python3 -c "import sys, json; print(json.load(sys.stdin)['AccessKeyId'])"`
        export AWS_SECRET_ACCESS_KEY=`echo $IAM_CREDS | python3 -c "import sys, json; print(json.load(sys.stdin)['SecretAccessKey'])"`
        export AWS_SESSION_TOKEN=`echo $IAM_CREDS | python3 -c "import sys, json; print(json.load(sys.stdin)['Token'])"`
        export AWS_SECURITY_TOKEN=$AWS_SESSION_TOKEN
        EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone -H "X-aws-ec2-metadata-token: $TOKEN"`
        EC2_REGION="`echo "$EC2_AVAIL_ZONE" | sed -e 's:\([0-9][0-9]*\)[a-z]*$:\1:'`"
        export AWS_DEFAULT_REGION=$EC2_REGION
        echo "$INSTID: Using $IAM_ROLE credentials."
    else
        echo "$INSTID: IAM role did not attached to this instance!"
    fi
fi
