#!/bin/bash
installProduct() {
    RETVAL=0
    echo "Install DataSunrise..." >> $PREP_LOG
    DS_INSTALLER=installer.rpm
    if [ -z "$DSDISTURL" ]; then
        echo " Distribution URL is empty. Using stock installer." >> $PREP_LOG
        ls -la
    else
        DS_INSTALLER=DSCustomBuild.rpm
        if [[ "${DSDISTURL:0:2}" == "S3" || "${DSDISTURL:0:2}" == "s3" ]]; then
            aws s3 cp "$DSDISTURL" $DS_INSTALLER --only-show-errors
        else
            wget "$DSDISTURL" -O $DS_INSTALLER -q
        fi
        if [[ "$?" != "0" ]]; then
            echo " Download was not successful, please check that URL is correct and available for downloading or S3AccessPolicy allows access to the bucket with the distribution file." >> $PREP_LOG
            echo " Installation will be interrupted." >> $PREP_LOG
            RETVAL=2
            return $RETVAL
        fi
    fi
    if [ -z "$DS_INSTALLER" ]; then
        echo "DataSunrise binary not found!" >> $PREP_LOG
        RETVAL=2
        return $RETVAL
    fi
    chmod +x $DS_INSTALLER
    echo "Using binary: $DS_INSTALLER" >> $PREP_LOG
    local DS_INSTALLER_CMD="rpm -ihv ./$DS_INSTALLER"
    $DS_INSTALLER_CMD
    RETVAL=$?
    systemctl stop datasunrise
    echo "Result of $DS_INSTALLER_CMD is $RETVAL" >> $PREP_LOG
    if [ "$RETVAL" != "0" ]; then
        return $RETVAL
    fi
    echo "Remove: $DS_INSTALLER" >> $PREP_LOG
    rm -f $DS_INSTALLER
    local DSCLOUDDIR="${DSCLOUDDIR}"
    echo "Configuring SELinux support" >> $PREP_LOG
    make -f /usr/share/selinux/devel/Makefile -C $DSCLOUDDIR datasunrise.pp
    semodule -i $DSCLOUDDIR/datasunrise.pp
    restorecon -vRF /opt/datasunrise/ > /dev/null
    semanage port -a -t datasunrise_port_t -p tcp 11000-11010
    semanage port -a -t datasunrise_port_t -p tcp $TRG_DBPORT
    echo "Turning on DataSunrise service" >> $PREP_LOG
    systemctl enable datasunrise
    echo "Turn on DataSunrise daemon" >> $PREP_LOG
    chkconfig datasunrise on
    local AF_GCNF=/etc/datasunrise.conf
    local ORACLE_HOME=/usr/lib/oracle/21/client64/lib
    echo "Setup $AF_GCNF..." >> $PREP_LOG
    echo "DS_SERVER_NAME_PREFIX=ds" | tee -a $AF_GCNF
    echo "AWS_PCODE=\"$AWS_AMI_PCODE\"" | tee -a $AF_GCNF    
    echo "ORACLE_HOME=$ORACLE_HOME" | tee -a $AF_GCNF
    echo "DS configuration file $AF_GCNF" >> $PREP_LOG
    cat $AF_GCNF
    
    if [ "$DSLICTYPE" == "BYOL" ]; then
        echo "Setup BYOL licensing model..." >> $PREP_LOG
        setupDSLicense
    else
        echo "Setup Hourly Billing licensing model..." >> $PREP_LOG
        cp appfirewall-hb.reg /opt/datasunrise/appfirewall.reg
    fi
    makeItMine
    # cleanLogs
    cleanSQLite
    echo "Install DataSunrise result - $RETVAL" >> $PREP_LOG
}
