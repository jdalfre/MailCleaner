#!/bin/bash

CLIENTID=`grep 'CLIENTID' /etc/mailcleaner.conf | sed 's/ //g' | cut -d '=' -f2`
HOSTID=`grep 'HOSTID' /etc/mailcleaner.conf | sed 's/ //g' | cut -d '=' -f2`
TIME=`date +%s`

DIRBASE='/var/mailcleaner/spool/watchdog/'
PIDDIR='/var/mailcleaner/run/watchdog/'
REPORTSWRK=$DIRBASE'reports.wrk'
FILE=$DIRBASE"reports/report-$CLIENTID-$HOSTID-$TIME.tar.gz"
WWW='/usr/mailcleaner/www/guis/admin/public/downloads/watchdogs.html'

if [ -e '/var/tmp/mc_checks_data.ko' ]; then
    exit;
fi

# Nettoyage
find $DIRBASE -type f -mtime +5 -exec rm {} \; > /dev/null 2>&1
find $PIDDIR -type f -mmin +120 -exec rm {} \; > /dev/null 2>&1

# Création du dossier temporaire, copie des fichiers et compression
if [ ! -d "$REPORTSWRK"  ]; then
    mkdir -p $REPORTSWRK >/dev/null 2>&1
else
    # Suppression des watchdogs plus agés que 15 jours
    find $REPORTSWRK -type f -mtime +5 -exec /bin/rm -f {} \; >/dev/null 2>&1
fi

# Création du dossier temporaire
if [ ! -d "$DIRBASE/reports"  ]; then
    mkdir -p $DIRBASE/reports >/dev/null 2>&1
fi

# Nothing to report
if [ `ls $DIRBASE/MC_mod_* 2> /dev/null | wc -l` ]; then
    mv $DIRBASE/MC_mod_*.out $REPORTSWRK/ >/dev/null 2>&1
else
    exit
fi

cd $DIRBASE >/dev/null 2>&1

# Admin console data
for i in `ls $REPORTSWRK`; do
    MODULE=`echo $i | sed 's/MC_mod_\(.*\)_[0-9]*.out/\1/'`
    DETAIL="`cat $REPORTSWRK/$i | head -n 1`"
    echo '<div>
    <h3 style="display: inline;">'$MODULE'</h3></br>
    <div>
        '$DETAIL'<br /><br />
    </div>
</div>' >> ${WWW}.tmp
done
if [ -e ${WWW}.tmp ]; then
    mv ${WWW}.tmp $WWW >/dev/null 2>&1
else
    echo "<br/>" > $WWW
fi

# Report to MailCleaner
if [ $CLIENTID ]; then
    tar cvf - reports.wrk 2>/dev/null  | gzip -9 - > $FILE
    scp -q -o PasswordAuthentication=no -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $FILE mcscp@team01.mailcleaner.net:/upload/watchdog-reports/ &> /dev/null
    if [[ $? = 0  ]]; then
        rm -Rf $REPORTSWRK >/dev/null 2>&1
        rm $FILE >/dev/null 2>&1
    else
        rm $FILE >/dev/null 2>&1
    fi
else
    rm -Rf $REPORTSWRK >/dev/null 2>&1
fi
