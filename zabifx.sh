#! /usr/bin/bash
  
#
# 2018-10-10 - by Cesar Inacio Martins - informix as imartins.com
#  script rewrite 
#  The Informix database version 12.10.FC10 doesn't support anymore the SNMP service.
#  So, since then, this script should be used to monitor everything on Informix database. 
#  Added resources where before is available at SNMP service.
#  Here was implemented two discovery, "intances" and "dbspaces".
#  Both return data in JSON format required by Zabbix Server.
#
 
# This script must be used with Zabbix Agent , just include into
# /etc/zabbix/zabbix-agentd.conf the line : 
#    UserParameter=zabifx[*],/etc/zabbix/zabifx $1 $2 $3
#  
#  Example how the key should be set at Zabbix item: zabifx[serverstatus,{#IFXSERVER}]
#  on shell this is converted to : /etc/zabbix/zabifx serverstatus ifxtest 
# 
# Macros from disovery process : 
#  1) {#IFXSERVER}    Returned by "instances" key , is the INFORMIXSERVER of each engine detected
#  2) {#IFXSERVERDBS} Returned by "dbspaces" key , where return the INFORMIXSERVER_DBSPACENAME detected

export vOption=$1
export INFORMIXSERVER=$2
export vOptionParam=$3

# Set your Informix variables here
# IMPORTANT: INFORMIXSERVER should be set before , for situations where have more than one instance
#          : in the same server with different INFORMIXDIR instalation.
#          : This way the YOUR script env.ifx.sh able to set correctly the variables.
source  /etc/zabbix/env.ifx.sh

# TECHINCAL ISSUE : The standard configuration of the Zabbix Agent for the systemd service enable the 
#                 : PrivateTmp parameter as default, where they "chroot" the /tmp access
#                 : So, everything saved there for userParamter script is lost .
#                 : Since this script intent to reuse the outputs of onstat command, need to save 
#                 : to another folder, I set to same directory of the script.

##############################################
# Commands 
#
  ONSTAT=$INFORMIXDIR/bin/onstat 
  GREP=grep
  # POSIXLY_CORRECT : to AWK parse equal on all OS the regular expressions... (on Linux this can be disabled)
  export POSIXLY_CORRECT=1 
  AWK=awk 
  SED=sed
  TR=tr
  CUT=cut
  DATE=date

#
# This is for AIX, where it is part of the RPM coreutils installed manually.
  [ -x /usr/linux/bin/date ] && DATE=/usr/linux/bin/date




###############################################
#
_help(){
echo "
 # Syntax $0 [key] [INFORMIXSERVER] [optional_parameter]
 #              key   : key used to identify the data to collect
 #                    : Discovery keys : instances - 
 #                    :                : dbspaces  - 
 #                    :                : sbspaces  - 
 #   INFORMIXSERVER   : The instance name
 # optional_parameter : Used with dbspaces* keys and sbspaces* keys
"
}

[[ $# -eq 0 || $* = "-h" ]] && _help && exit 1

###############################################
#
# Expected receive 2 parameters
# Example :  zabifx sessioncout ifxonline
# Example, just for test if the scripts is working:  zabifx all <instance_name>
if [ $# -ne 2 -a $# -ne 3 ] ; then 
  echo "ZBX_NOTSUPPORTED"
  exit 1
fi

# If INFORMIXSERVER = - , blank it (not unset because it already is exported)
[ "$INFORMIXSERVER" = "-" ] && INFORMIXSERVER=

# In minutes...
vONSTAT_CACHE=2


###############################################
#
# Use a temporary file (just in case resquested all parameters together, run only once each onstat)
# Theses temporarys are kept for 2 minutes to avoid overloading the "onstat" calls
vTmpName=tmp.zabifx.${INFORMIXSERVER:-null}
vTmpDir=$(dirname $0)
[ ! -z "$vZBX_DIR" ] && vTmpDir=$vZBX_DIR
vTmp=$vTmpDir/$vTmpName
vTmp1=${vTmp}.1

# Remove temporary files with than 2 minutes to no reuse them.
find $vTmpDir -name "$vTmpName*" -mmin +$((vONSTAT_CACHE -1)) -maxdepth 1 -exec rm -f {} \; 2>/dev/null 

# Check if onstat is accessible
if [ ! -x $ONSTAT ] ; then 
  echo "ZBX_NOTSUPPORTED"
  exit 1
fi

##############################################
#
_onstat_status(){
  export vOnstatStatus=""
  $ONSTAT -  > $vTmp1.${INFORMIXSERVER}.onstat-
  vOnstatStatus=$? # 5 = online # 2 = Recovery (restore/rss/hdr)
  chmod 666 $vTmp1.${INFORMIXSERVER}.onstat- 2>/dev/null
  export vForce=0
}
_onstat_status

##############################################
###
# function to capture the onstat outputs 
# (useful only when used the "all" cmdline parameter, avoiding run multiple times the same onstat )
_onstat(){
  if [ $vOnstatStatus -eq 5 -o $vOnstatStatus -eq 2 ] ; then 
    vParam=$(echo "$*" | $TR -d " " )
    if [ ! -f $vTmp1.${INFORMIXSERVER}.onstat.$vParam -o ${vForce:-0} -eq 1 ] ; then 
      $ONSTAT $*   > $vTmp1.${INFORMIXSERVER}.onstat.$vParam 2>/dev/null 
      chmod a+rw $vTmp1.${INFORMIXSERVER}.onstat.$vParam 2>/dev/null 
    fi
    vForce=0
    cat $vTmp1.${INFORMIXSERVER}.onstat.$vParam
  fi 
}


##############################################
###
_param() { 
  vParam1=$1
  vParam2=$2
  [[ ! $vParam1 =~ ^(instances|serverstatus|dbspaces|sbspaces)$ ]] && [ "$vOnstatStatus" != 5 -a "$vOnstatStatus" != 2 ] && echo "${vParam1}|ZBX_NOTSUPPORTED" && return
  case ${vParam1} in
    # Return Server Status , # 0   Initialization mode
                             # 1   Quiescent mode
                             # 2   Recovery mode
                             # 3   Backup mode
                             # 4   Shutdown mode
                             # 5   Online mode
                             # 6   Abort mode
                             # 7   User mode
                             # 255     Off-Line mode
    serverstatus) echo "${vParam1}|$vOnstatStatus"  ;;
    # INSTANCES DISCOVERY
    # This is a special threatment, because this parameter should be used to discovery the instances in this machine
    # and the Zabbix Server requires its return in JSON format.
    instances) 
               # The awk+sed below should create a JSON array like that (without identation)
               # based on output of the command "onstat -g dis" .
               # {
               #    "instances":[
               #       {
               #          "{#IFXSERVER}":"ifxdesenv2",
               #          "{#IFXSERVERSTATUS}":"Up",
               #          "{#IFXMSGPATH}":"/opt/informix/tmp/ifxdesenv2.log"
               #       },    
               #       {     
               #          "{#IFXSERVER}":"ifxdesenv1",
               #          "{#IFXSERVERSTATUS}":"Up",
               #          "{#IFXMSGPATH}":"/opt/informix/tmp/ifxdesenv1.log"
               #       }
               #    ]
               # }
             value=$( 
               printf '%s' ${vParam1}'|{"data":['
               onstat -g dis > $vTmp1.og-dis
               vIfxServer=""
               while read vLinha 
               do
                 if   [[ $vLinha =~ ^Server\ *: ]]        ; then 
                   # If vIfxServer already set, it isnt the first of...
                   #   print the comma between {}
                   [ ! -z "$vIfxServer" ] && printf ","
                   #
                   vIfxServer=${vLinha#*:}  ## syntaxe ${...#*:} remove prefixo *:
                   #
                   vIfxServerStatus=""
                   vIfxDir=""
                   vIfxOnconfig=""
                   vIfxMsgPath=""
                   printf '{ "{#IFXSERVER}":"%s",' $vIfxServer
                 elif [[ $vLinha =~ ^Server\ Status\ *: ]] ; then 
                   vIfxServerStatus=${vLinha#*:}
                   printf '"{#IFXSERVERSTATUS}":"%s",' $vIfxServerStatus
                 elif [[ $vLinha =~ ^INFORMIXDIR ]]      ; then 
                   vIfxDir=${vLinha#*:}
                 elif [[ $vLinha =~ ^ONCONFIG ]]         ; then 
                   vIfxOnconfig=${vLinha#*:}
                   vIfxMsgPath=$(awk '$1 == "MSGPATH" { print $2 ; exit } ' $vIfxOnconfig )
                   vIfxMsgPath=$(echo $vIfxMsgPath | sed -e "s,\$INFORMIXDIR,$vIfxDir,")
                   printf '"{#IFXMSGPATH}":"%s"' $vIfxMsgPath
                   printf '}'
                 fi
               done < $vTmp1.og-dis
               echo "]}"
             )
             if echo "$value" | grep -q "#IFX" ; then 
               echo "$value" 
             else
               echo "ZBX_NOTSUPPORTED"
             fi
             ;;
    # DBSPACE DISCOVERY
    # This is a special threatment, because this parameter should be used to discovery the dbspaces of each instances in this machine
    # 
    # {
    #    "data":[
    #       {
    #          "{#IFXSERVER}":"ifxdesenv2",
    #          "{#IFXDBSPACE}":"rootdbs"
    #       },
    #       {
    #          "{#IFXSERVER}":"ifxdesenv2",
    #          "{#IFXDBSPACE}":"llogdbs"
    #       },
    #       {
    #          "{#IFXSERVER}":"ifxdesenv2",
    #          "{#IFXDBSPACE}":"plogdbs"
    #       },
    #       {
    #          "{#IFXSERVER}":"ifxdesenv1",
    #          "{#IFXDBSPACE}":"rootdbs"
    #       },
    #       {
    #          "{#IFXSERVER}":"ifxdesenv1",
    #          "{#IFXDBSPACE}":"softeldat1dbs"
    #       }
    #    ]
    # }
    dbspaces|sbspaces)
             echo "${vParam1}|{\"data\":["
             # Execute for each instance
             {
             for INFORMIXSERVER in $(onstat -g dis | $AWK '/^Server *:/  { print $NF}')
             do 
               # Force update the status of each instance.
               _onstat_status
               _onstat "-d" | \
                 $AWK -v FS='\n' -v RS='' '/^Dbspaces/' | \
                 $AWK -v i=$INFORMIXSERVER -v vOpcao=$vParam1 '
                   #
                   # Identify position of the second "flags" columns 
                   /^address/ { x=index($0,"pgsize")+6 ; xx=index(substr($0,30),"flags")+29+5; vFlagI=x ; vFlagL=xx-x } 
                   #
                   # Skip lines
                   /^Dbspace|^address|active.*maximum/ { next } 
                   #
                   # get the flags
                   {
                     flag=substr($0,vFlagI,vFlagL)
                     gsub(/^ *| *$/,"",flag)
                     #
                     # if sbspaces , filter ...
                     if ( vOpcao == "sbspaces" && flag !~ /^..[SU]/ ) { next } 
                   }
                   #
                   # print the data
                   { printf "{ \"{#IFXSERVER}\":\""i"\""
                     printf ",\"{#IFXDBSPACE}\":\""$NF"\"  " 
                     print  ",\"{#IFXDBSPACEFLAG}\":\""flag"\" } " 
                   }
                   '
             done
             } | awk 'NR>1 { printf "," } {print}' ## add comma between lines
             echo "]}"
 
             ;;
    #
    # Return # of users sessions connected 
    sessioncount) printf "${vParam1}|" ; 
               _onstat "-g glo" | $AWK -v FS='\n' -v RS='' '/^MT global/' | $AWK '$1 == "sessions" { getline ; print $1 ; exit }'
               ;;
    # Return # max of users sessions connected since the database started (or last onstat -z)
    topsessioncount) printf "${vParam1}|" ; 
               _onstat "-g ntu" | \
                 $AWK '/#netscb/ { vNext=1 ; next } vNext == 1 { match($1,"/.*"); x=substr($1,RSTART+1, RLENGTH); print x; exit} '
               ;;
    # Return # system threads 
    systemthreads) printf "${vParam1}|" ; 
               _onstat "-g ath"  | \
               $GREP -E -v 'sqlexec|xchg_' | \
                 $AWK '$1 ~ /[[:digit:]]+/' | $GREP -c "."
               ;;
     # Return # threads 
    totalthreads) printf "${vParam1}|" ; 
               _onstat "-g glo" | $AWK -v FS='\n' -v RS='' '/^MT global/' | $AWK '$2 == "threads" { getline ; print $2 ; exit }'
               ;;
    # Return # read threads, waiting CPU to run
    threadread) printf "${vParam1}|" ; 
               _onstat "-g rea" | \
                 $GREP -c "ready"
               ;;
    # Return # active user threads , running on CPU
    activesessioncount) printf "${vParam1}|" ; 
               _onstat "-g act" | \
                 $GREP -cE "aio|sqlexec"
               ;;
    # Return # user sessions waiting for something what isn't Yield, Lock (mutex or any other condition)
    userwaiting) printf "${vParam1}|" ; 
               vForce=1
               _onstat "-u"  | \
                 $AWK '$2 ~ /^[A-Z-]{7}$/ {print $2}' | $GREP -c "^[^YL-]"
               ;;
    # Return # user sessions waiting for lock
    userlockwaiting) printf "${vParam1}|" ; 
               vForce=1
               _onstat "-u"  | \
                 $AWK '$2 ~ /^[A-Z-]{7}$/ {print $2}' | $GREP -c "^L"
               ;;
    # Return current logical logs 
    llogcurrent) printf "${vParam1}|" ; 
               _onstat "-l" | \
                 $AWK  '$3 ~ /^[A-Z-]{7}$/ && /C/ {print $4}'
               ;;
     # Return # logical logs without backup 
    llogwithoutbkp) printf "${vParam1}|" ; 
               _onstat "-l" | \
                 $AWK '$3 ~ /^[A-Z-]{7}$/ {print $3}'  | $GREP -c '^U.-'
               ;;
    # Return % logical logs without backup 
    llogwithoutbkpperc) printf "${vParam1}|" ; 
               logstotal=$(_onstat "-l" | $AWK '/[0-9]+ active/ { print $1}')
               logswb=$(_onstat "-l" | \
                 $AWK '$3 ~ /^[A-Z-]{7}$/ {print $3}'  | $GREP -c '^U.-')
               echo $logswb $logstotal | $AWK ' {x= $1 * 100  / $2 ; print x} '
               ;;
    # Return Physical Log size in bytes
    physize) printf "${vParam1}|" ; 
               # Identifica qual chunk esta o physical log
               phybegin=$(_onstat "-l"  | $AWK -v FS='\n' -v RS='' '/Physical Logging/ {print}' | $AWK '$1=="phybegin" { getline ; print $1 ; exit}'  | cut -f1 -d:)
               # Pega o pagesize do chunk
               pagesize=$(_onstat "-d" | $AWK -v FS='\n' -v RS='' '/^Dbspaces/' | $AWK -v vDB=$phybegin '$4 == vDB { print $6 ; exit}')
               # Pega o physize em paginas
               physize_pg=$(_onstat "-l" | $AWK -v FS='\n' -v RS='' '/Physical Logging/ {print}' | $AWK '$2=="physize" { getline ; print $2 ; exit }')
               # Calcula em bytes
               physize=$(expr ${physize_pg:-0} \* ${pagesize:-})
               echo $physize
               ;;
    # Return Physical Log used in bytes
    phyused) printf "${vParam1}|" ; 
               # Identifica qual chunk esta o physical log
               phybegin=$(_onstat "-l"  | $AWK -v FS='\n' -v RS='' '/Physical Logging/ {print}' | $AWK '$1=="phybegin" { getline ; print $1 ; exit}'  | cut -f1 -d:)
               # Pega o pagesize do chunk
               pagesize=$(_onstat "-d" | $AWK -v FS='\n' -v RS='' '/^Dbspaces/' | $AWK -v vDB=$phybegin '$4 == vDB { print $6 ; exit}')
               # Pega o phyused em paginas
               phyused_pg=$(_onstat "-l" | $AWK -v FS='\n' -v RS='' '/Physical Logging/ {print}' | $AWK '$4=="phyused" { getline ; print $4 ; exit }')
               # Calcula em bytes
               physused=$(expr ${phyused_pg:-0} \* ${pagesize:-})
               echo $physused
               ;;
    # Return the # of RSS servers configured
    rssservers) printf "${vParam1}|" ; 
               _onstat "-g rss verbose" | $AWK '/Number of RSS servers/ { print $NF } '
               ;;
    # Return the # of active connection of all RSS servers configured
    rssconnactive) printf "${vParam1}|" ; 
               _onstat "-g rss verbose" | $AWK -F: 'BEGIN {x=0} /Log transmission status/ { if ($NF ~ "Active") x=x+1 } END { print x } '
               ;;
    # Return the total of backlog (~ delay) of all RSS servers configured
    rssbacklog) printf "${vParam1}|" ; 
               _onstat "-g rss verbose" | $AWK -F: 'BEGIN {x=0} /Approximate.*Backlog/ { x=x+$NF } END { print x}'
               ;;
    # Return # of Foregroud Writes
    lruwrites) printf "${vParam1}|" ; 
              _onstat "-F"  | \
                  $AWK '$0 ~ /LRU Writes/ { getline ; print $2 ; exit }'
               ;;
     # Return # of Foregroud Writes
    fgwrites) printf "${vParam1}|" ; 
              _onstat "-F"  | \
                  $AWK '$0 ~/^Fg Writes/ { getline ; print $1 ; exit }'
               ;;
     # Return # of deadlocks
    deadlocks) printf "${vParam1}|" ; 
              _onstat "-p"  | \
                  $AWK '$4 == "deadlks" { getline ; print $4 ; exit }'
               ;;
    # Return # of checkpoints waits
    checkpoint_waits) printf "${vParam1}|" ; 
              _onstat "-p"  | \
                  $AWK '$6 == "ckpwaits" { getline ; print $6 ; exit }'
               ;;
    # Return # of checkpoints 
    checkpoints) printf "${vParam1}|" ; 
              _onstat "-p"  | \
                  $AWK '$6 == "numckpts" { getline ; print $6 ; exit }'
               ;;
    # Return text with version of the database
    checkpoint_inprogress) printf "${vParam1}|" ; 
              vForce=1
              _onstat "-"  | \
                  $GREP -q "CKPT" && echo "1" || echo "0"
               ;;
    # Return text with version of the database
    version) printf "${vParam1}|" ; 
              _onstat "-"  | \
                 $GREP "Version" | $AWK -F"--" '{print $1}' 
               ;;
    # Return # seconds the database is UP. 
    # Requires the GNU date command , where support the @0 parameter
    uptime) printf "${vParam1}|" ; 
             vUPstr=$(_onstat "-" | $GREP " Up " | $AWK -F"--" '{print $3}' )
             vUPhour=$(echo "$vUPstr" | $SED -e 's/ *Up *//g'  -e 's/.*days *//g') # return HH:MM:SS
             vUPhour=$(echo "$vUPhour" | $AWK -F: '{ printf " %s hour + %s minutes ",$1,$2} ')
             vUPdays=""
             if echo "$vUPstr" | $GREP -q "days" ; then 
               vUPdays=" + $(echo "$vUPstr" | $SED -e 's/ *Up *//g'  -e 's/ *days .*//g') days " # return DD
             fi
             vTimeStamp=$($DATE -d "1970-01-01 UTC $vUPdays + $vUPhour " +%s  2>&1 ) 
             if [ $? -eq 0 ] ; then 
               echo "$vTimeStamp"
             else
               echo "ZBX_NOTSUPPORTED"
               break
             fi
             ;;
    # Return Y o N to Logical log Backup automatic (alarmprogram parameter)
    llogautobkp) printf "${vParam1}|" ; 
             alarmprogram_script=$(_onstat "-c" | $AWK '$1 == "ALARMPROGRAM" {print $2}' )
             alarmprogram_script=$(eval "echo $alarmprogram_script")
             [ -z "$alarmprogram_script" ] && alarmprogram_script=$INFORMIXDIR/etc/alarmprogram.sh
             backup_auto=$($AWK -F= '/^ *BACKUPLOGS=/ {print $2 ; exit}' ${alarmprogram_script} )
             if [ "$backup_auto" = "Y" -o "$backup_auto" = "y" ] ; then 
               echo "1"
             else
               echo "0"
             fi
             ;;
    # Return # of VPs
    vps) printf "${vParam1}|" ; 
             value=$(_onstat "-g glo" | $AWK -v FS='\n' -v RS='' '/^MT global/' | $AWK '$3 == "vps" { getline ; print $3 ; exit }')
             if [ ! -z "$value" ] ; then 
               echo "$value"
             else
               echo "ZBX_NOTSUPPORTED"
             fi
             ;;
     # Return total consumption for VP
    vp_*) printf "${vParam1}|" ; 
             vp=$(echo "${vParam1}" | cut -c4- )
             value=$(_onstat "-g glo" | awk -v FS='\n' -v RS='' '/^Virtual processor/' | awk -v vp=$vp '$1 == vp { print $3 } ')
             if [ ! -z "$value" ] ; then 
               echo "$value"
             else
               echo "ZBX_NOTSUPPORTED"
             fi
             ;;
    # Dbspace monitor
    dbspacesize|dbspacefree|dbspaceused) 
                printf "${vParam1}|"   
                vPrint=0
                # ${vDBS[0]}=number, ${vDBS[1]}=pgsize ,${vDBS[2]}=name 
                vDBS=($( _onstat "-d"  | $AWK -v vDBS=${vParam2} 'vDBS == $NF {print $2,$6,$NF ; exit } ' ))
                #
                if [[ ! -z "${vDBS[*]}" ]] ; then 
                  #  vnDbs  : Numero do DbSpace
                  #  vPgSize: Page Size
                  #  vDbs   : Nome do DbSpace
                  #  echo $vnDbs $vPgSize $vDbs
                  _onstat "-d" | $AWK -v FS='\n' -v RS='' '/^Chunks/' | \
                    $AWK -v vOpcao=${vParam1} -v vnDbs=${vDBS[0]} -v vDbs="${vDBS[2]}" -v vV="m" -v vPg=${vDBS[1]} '
                    BEGIN { 
                            if (vV == "b") vV=1;
                            if (vV == "k") vV=1024;
                            if (vV == "m") vV=1024*1024;
                            if (vV == "g") vV=1024*1024*1024;
                            #-#if (vPg > 1000) vPg=vPg/1024;
                    }
                    $3 == vnDbs { 
                      alloc=alloc+$5; free=free+$6;
                     }
                      END {
                        if (NR==0) {
                          print "ZBX_NOTSUPPORTED"
                          exit
                        }
                        talloc = (alloc*vPg)/vV
                        tfree = (free*vPg)/vV
                        tused = talloc - tfree
                        #printf "%18s : Alocado = %-10.2f : Utilizado = %-10.2f : Free = %-10.2f : PgSize = %i : \n" ,
                        if (vOpcao ~ "dbspacesize") printf "%-10.2f\n" , talloc
                        if (vOpcao ~ "dbspacefree") printf "%-10.2f\n" , tfree
                        if (vOpcao ~ "dbspaceused") printf "%-10.2f\n" , tused
                      }'
                 else
                   echo "ZBX_NOTSUPPORTED"
                 fi 
                 ;;
    # Dbspace flag
    dbspaceflag|sbspaceflag)
                printf "${vParam1}|"   
                value=$(_onstat "-d" | $AWK -v FS='\n' -v RS='' '/^Dbspace/' |\
                $AWK -v vDBS=$vParam2 '
                   #
                   # Identify position of the second "flags" columns 
                   /^address/ { x=index($0,"pgsize")+6 ; xx=index(substr($0,30),"flags")+29+5; vFlagI=x ; vFlagL=xx-x } 
                   #
                   # Skip lines
                   /^Dbspace|^address|active.*maximum/ { next } 
                   #
                   # print the data
                   $NF == vDBS {
                     flag=substr($0,vFlagI,vFlagL)
                     gsub(/^ *| *$/,"",flag)
                     print flag
                   }
                   ')
                if [ ! -z "$value" ] ; then 
                  echo "$value"
                else
                  echo "ZBX_NOTSUPPORTED"
                fi
                ;;
    # SBspace monitor
    sbspacesize|sbspacefree|sbspaceitems) 
                printf "${vParam1}|"   
                vPrint=0
                # ${vDBS[0]}=number, ${vDBS[1]}=pgsize ,${vDBS[2]}=name 
                vDBS=($( _onstat "-d"  | $AWK -v vDBS=${vParam2} 'vDBS == $NF {print $2,$6,$NF ; exit } ' ))
                #
                if [[ ! -z "${vDBS[*]}" ]] ; then 
                  #  vnDbs  : Numero do DbSpace
                  #  vPgSize: Page Size
                  #  vDbs   : Nome do DbSpace
                  #  echo $vnDbs $vPgSize $vDbs
                  if  [ "${vParam1}" = "sbspaceitems" ]  ; then 
                    _onstat "-g smb e " | grep -c "\[${vDBS[0]},"  
                  else
                    _onstat "-g smb c " |\
                    $AWK -v vOpcao=${vParam1} -v vnDbs=${vDBS[0]} -v vDbs="${vDBS[2]}" -v vV="m" -v vPg=${vDBS[1]} '
                      BEGIN { 
                              if (vV == "b") vV=1;
                              if (vV == "k") vV=1024;
                              if (vV == "m") vV=1024*1024;
                              if (vV == "g") vV=1024*1024*1024;
                              #-#if (vPg > 1000) vPg=vPg/1024;
                      }
                      /^sbnum/ && $2 == vnDbs { 
                        ##sb=$2SUBSEP$4 ; 
                        sb=$2 
                        getline ; getline ; 
                        sb_size[sb]=+($4*vPg)/vV ; 
                        sb_free[sb]=+($7*vPg)/vV ; 
                      } 
                      END { 
                        if (vOpcao ~ "sbspacesize") printf "%-10.2f\n" , sb_size[sb]
                        if (vOpcao ~ "sbspacefree") printf "%-10.2f\n" , sb_free[sb]
                      } 
                      '
                  fi 
                 else
                   echo "ZBX_NOTSUPPORTED"
                 fi 
                 ;;

    # Return memory free
    mem*free) printf "${vParam1}|" ; 
             vClass=""
             case ${vParam1} in 
               memresfree) vClass=R  ;;
               memvirfree) vClass=V  ;;
               memextfree) vClass=VX ;;
               membuffree) vClass=B  ;;
               memtotfree) vClass=-  ;;
               *) vClass='zzz' ;;
             esac
             value=$(_onstat "-g seg" | $AWK -v vClass=$vClass '$1 == "id" , $1 =="Total:" { x=NF-2 ; y=NF ; if ( $x ~ vClass ) vI=vI+$y ; } END {printf "%.0f\n", vI*4096}')
             if [ ! -z "$value" ] ; then 
               echo "$value"
             else
               echo "ZBX_NOTSUPPORTED"
             fi
             ;;
    # Return memory used
    mem*used) printf "${vParam1}|" ; 
             vClass=""
             case ${vParam1} in 
               memresused) vClass=R  ;;
               memvirused) vClass=V  ;;
               memextused) vClass=VX ;;
               membufused) vClass=B  ;;
               memtotused) vClass=-  ;;
               *) vClass='zzz' ;;
             esac
             value=$(_onstat "-g seg" | $AWK -v vClass=$vClass '$1 == "id" , $1 =="Total:" { x=NF-2 ; y=NF-1 ; if ( $x ~ vClass ) vI=vI+$y ; } END {printf "%.0f\n", vI*4096}')
             if [ ! -z "$value" ] ; then 
               echo "$value"
             else
               echo "ZBX_NOTSUPPORTED"
             fi
             ;;
    # Return total memory allocated
    memtotaloc) printf "${vParam1}|" ; 
             value=$( _onstat '-g seg' | awk '/^Total:/ { print $4}')
             if [ ! -z "$value" ] ; then 
               echo "$value"
             else
               echo "ZBX_NOTSUPPORTED"
             fi
             ;;
    # Return the path of ONLINE.LOG 
    shmtotal) printf "${vParam1}|" ; 
             eval "echo $(_onstat "-c" | $AWK '$1 == "SHMTOTAL" {print $2*1024 ; exit }' )"
             ;;
     # Return the path of ONLINE.LOG 
    msgpath) printf "${vParam1}|" ; 
             eval "echo $(_onstat "-c" | $AWK '$1 == "MSGPATH" {print $2 ; exit }' )"
             ;;
    # Return the instance name
    instance) echo "${vParam1}|$INFORMIXSERVER" 
             ;;
     # Return # network accepted
    network_accepted) printf "${vParam1}|" ; 
              _onstat "-g ntd"  | $AWK '$1 == "Totals" { print $2} '
               ;;
    # Return # network rejected
    network_rejected) printf "${vParam1}|" ; 
              _onstat "-g ntd"  | $AWK '$1 == "Totals" { print $3} '
               ;;
    # Return # network reads
    network_reads) printf "${vParam1}|" ; 
              _onstat "-g ntd"  | $AWK '$1 == "Totals" { print $4} '
               ;;
    # Return # network writes
    network_writes) printf "${vParam1}|" ; 
              _onstat "-g ntd"  | $AWK '$1 == "Totals" { print $5} '
               ;;
    # Return # of Buffer waits
    buffer_flushes) printf "${vParam1}|" ; 
              _onstat "-p"  | \
                  $AWK '$7 == "flushes" { getline ; print $7 ; exit }'
               ;;
    # Return # of Buffer waits
    buffer_waits) printf "${vParam1}|" ; 
              _onstat "-p"  | \
                  $AWK '$1 == "bufwaits" { getline ; print $1 ; exit }'
               ;;
    # Return # of Latches waits
    latches_waits) printf "${vParam1}|" ; 
              _onstat "-p"  | \
                  $AWK '$6 == "lchwaits" { getline ; print $6 ; exit }'
               ;;
    *) echo "$vParam1|ZBX_NOTSUPPORTED"
      ;;
  esac
} ##### _param
###
##############################################

if [ "$vOption" = "all" ] ; then 
 for x in instance serverstatus sessioncount activesessioncount topsessioncount llogcurrent llogwithoutbkp llogwithoutbkpperc physize rssservers rssbacklog rssconnactive version checkpoint_inprogress checkpoints checkpoint_waits deadlocks lruwrites fgwrites uptime threadread llogautobkp systemthreads totalthreads vps vp_cpu vp_aio vp_lio vp_pio vp_adm vp_soc vp_msc vp_ssl vp_fifo vp_enc vp_idsxmlvp vp_bts memvirfree memresfree memextfree membuffree memtotfree memvirused memresused memextused membufused memtotused memtotaloc shmtotal msgpath network_accepted network_rejected network_reads network_writes buffer_waits buffer_flushes latches_waits
  do 
    _param $x $vOptionParam
  done 
else
  _param $vOption $vOptionParam | $CUT -f2 -d"|"
fi

