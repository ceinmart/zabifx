--------------------------------------------------------------
13/jun/2013
by Cesar Inacio Martins - informix at imartins.com.br
--------------------------------------------------------------
Changelog 
 08/ago/2013 - Changed the template and zabifx scripts.
               added item to monitor # of threads ready (onstat -g rea) into the
			   template and zabifx
			   Little change of priority on Sessions in wait trigger
 20/jun/2013 - Correction on template, two items have wrong keys (Physical Log)
               Added new trigger for sessions in waits (not lock wait)
 18/jun/2013 - Correction on zabifx script, where miscalculate the uptime 
               information when the engine is less 1 day up and miscalculate
			   the minutes.
--------------------------------------------------------------
Index
- About this Template_Informix
- About SNMP
- About SNMP and Informix
- How active the SNMP service on Informix?
- How the SNMP itens was discovered and included into this Template?
- Limitations / attention / caution:
--------------------------------------------------------------
About this Template_Informix

    This template was created , tested and used successfully
    on Zabbix 2.0.5 (rpm opensuse 12.3 distribution) monitoring two
    IBM Informix v11.50 FC9 running over AIX 6.1 and AIX 5.3 .
   
    They objective was monitor Informix instances only with SNMP.
    But unfortunatelly I discovery during the implementation this isn't possible
    because of fews limitations of Informix SNMP service and others of Zabbix 2.0.5.

    It was prepared to discovery the Informix instances dynamically by SNMP
    protocol and use this same SNMP protocol to capture the data.
    A plus what I was forced to implement into it is the "zabifx" shell script
    where is prepared to be used with zabbix agent installed and configured on
    same machine/OS where the Informix instance/SNMP is running.
   

--------------------------------------------------------------
About SNMP
    Before start here, make sure you is familiar about the concept and how
    work with SNMP service (master agents, sub-agents, MIBs, utilities like
    snmpwalk, etc).
    Here you found a start: http://en.wikipedia.org/wiki/Simple_Network_Management_Protocol  
      
--------------------------------------------------------------
About SNMP and Informix
    Informix have a special service for SNMP where is installed on default
    installation, you will found it on : $INFORMIXDIR/snmp
    **** As far I know , there is no additional licence to use it.
   
    There you will found the runsnmp.ksh script and .mib files rdbms, apps, omni
    for SNMP v1 and v2. For this template I was used the SNMP v2 MIBs .
   
    You can found the last documentation (Informix v12.10) here :
      http://pic.dhe.ibm.com/infocenter/informix/v121/topic/com.ibm.snmp.doc/snmp.htm
    or PDF here:
      http://www-01.ibm.com/support/docview.wss?uid=swg27023505
   
    Informix offer the SNMP Master agent and the sub-agent.
    On "perfect world" , you should use only the sub-agent and integrate it
    with the Master Agent of your machine/OS where Informix is running
    (supposing have a SNMP service active on your OS)
    But this requires some compatibility and manual configuration (very annoying)
    If you want try this, please read the official documentation/manual.
   
    In past I already try configure the Informix sub-agent with Linux Red Hat
    Master Agent, without success, the workaround is use the Informix SNMP
    Master Agent.
    Today I work with AIX environment and to keep it simple I choose
    work with Informix SNMP Master Agent (I not try configure the Informix
    sub-agent with AIX SNMP Master Agent). Our AIX have SNMP service active, this
    way we have two Master Agent on same OS, what is 100% possible, but requires
    adjustments of the configuration on Informix SNMP Master Agent.
   
    Delay on recent releases:
    The SNMP service seems to have been forgotten by engineers from IBM and
    a lot of new features aren't included into it.
    I have open a feature request on IBM RFE site to improve/update the SNMP service:
        Headline: improve/update SNMP service
        ID: 35921
        http://www.ibm.com/developerworks/rfe/execute?use_case=viewRfe&CR_ID=35921
    If you have interest on it , please follow the link, sign up and vote on
    the feature, if have suggestion use the comment tab.
   
   
--------------------------------------------------------------
How active the SNMP service on Informix?
    Is quite simple, but have a pre-requisite : the SNMP service *needs* run with root user.
    * Log in with root
    * Set your informix enviroment (INFORMIXSERVER, INFORMIXDIR, INFORMIXSQLHOSTS, etc)]
    * cd $INFORMIXDIR/snmp
    * ./runsnmp.ksh start
    And finish!!!
   
    If you already have a Master Agent running on same OS, you can change the
    port used by Informix SNMP Master Agent, for example, changing to port 5161.
    (off course, we need adapt the template to use the correct port)
    * INFORMIXSNMPPORT=5161 ./runsnmp.ksh start
      The output should be something like :
       | runsnmp.ksh FYI   - Using INFORMIXDIR: /xxx/informix
       | runsnmp.ksh FYI   - Using INFORMIXSNMPPORT = 5161
       | runsnmp.ksh FYI   - Setting SR_SNMP_TEST_PORT to 5161
       | runsnmp.ksh FYI   - Setting SR_TRAP_TEST_PORT to 162
       | runsnmp.ksh FYI   - Setting SR_AGT_CONF_DIR to /xxx/informix/snmp/snmpr
       | SNMP Research EMANATE Agent Version 16.2.0.27
       | Copyright 1989-2007 SNMP Research, Inc.
       | runsnmp.ksh FYI   - The SNMP Research Inc. master agent (snmpdm) started (pid  13107646).
       | runsnmp.ksh FYI   - The server discovery daemon (onsrvapd) started (pid  13434922).
    Will be created tree LOG files (Master, srvprd, sub-agent) on /tmp (by default) :
       | /tmp> ls -ltr on*log *snmp*
       | -rw-rw-r--    1 informix informix       1090 Jun 10 17:22 onsrvapd.517185c724026.log
       | -rw-rw-r--    1 informix informix       4011 Jun 11 08:06 onsnmp.idsbkp.517185c8580f4.log
       | -rw-------    1 root     system      9204234 Jun 13 12:10 snmpd.log


    If you check your PIDs with ps -fe , you should found at least 3 PIDs : snmpdm, onsrvapd and onsnmp
    bellow is the output on my AIX 5.3 where the snmpmibd and snmpd is the AIX SNMP service.
       | > ps -fe | egrep "snmp|onsrv"
       |     root 135182  77830   0   Apr 19      -  4:35 /usr/sbin/snmpmibd
       |     root 143414  77830   0   Apr 19      -  8:27 /usr/sbin/snmpd
       | informix 147494      1   0   Apr 19      -  8:54 /xxx/informix/bin/onsrvapd
       |     root 356500      1   0   Apr 19      -  3:39 /xxx/informix/bin/snmpdm (5161)
       | informix 360692 147494   0   Apr 19      - 6046:38 onsnmp -nidsbkp -k5 -p5 -l/tmp -g32 -r4

        * Master Agent = snmpdm
        * Server Discovery = onsrvapd
             The discovery process discovers multiple server instances running on the host.
             These instances might belong to different versions that are installed on different
             directories. Whenever a server instance is brought online, the discovery process
             detects it and spawns an instance of OnSNMP to monitor the database server.
        * Sub Agent = onsnmp
      
--------------------------------------------------------------
How the SNMP items was discovered and included into this Template?

	* First I was used the Zabbix plugin SNMP Browser
	    https://www.zabbix.com/wiki/howto/monitor/snmp/snmp_builder
	    https://github.com/atimonin/snmpbuilder
	  For each item showed what I have interest to monitor , I have added
	  manually into the template.
	
	Since this plugin isn't prepared to Zabbix 2.0.5 (when I download it) I need 
	to patch it manually and do some manual adjustments to work. After that 
	works fine, but be careful, I lost it when I update my zabbix with the 
	RPM manager(zypper/opensuse).
	
	* Other way I use is the smnpwalk command on Linux BOX (net-snmp RPM package),
	with this command I able to identify the items too.
	(for nice output need to copy the *V2.mib files from $INFORMIXDIR/snmp
	to /usr/share/snmp/mibs , this on OpenSuse 12.3, this location may vary on
	other Linux distribution)
		| $ snmpwalk -m Informix-MIB -c public -v 2c 101.0.123.220:5161 | head
		| SNMPv2-MIB::sysDescr.0 = STRING: AIX release:3 version:5 machine:00C44DEF4C00
		| SNMPv2-MIB::sysObjectID.0 = OID: SNMPv2-SMI::zeroDotZero
		| DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (25647272) 2 days, 23:14:32.72
		| SNMPv2-MIB::sysContact.0 = STRING: SNMP Research Inc., +1 (865) 573-1434, info@snmp.com
		| SNMPv2-MIB::sysName.0 = STRING: P550.xxx.corp
		| SNMPv2-MIB::sysLocation.0 = STRING:
		| SNMPv2-MIB::sysServices.0 = INTEGER: 72
		| SNMPv2-MIB::snmpInPkts.0 = Counter32: 41470
		| SNMPv2-MIB::snmpOutPkts.0 = Counter32: 41519
		| SNMPv2-MIB::snmpInBadVersions.0 = Counter32: 0
		|
		| $ snmpwalk -m Informix-MIB -c public -v 2c 101.0.123.220:5161 | grep -i start
		| RDBMS-MIB::rdbmsSrvInfoStartupTime.893002000 = STRING: 2013-4-22,12:6:39.0,+3:0
		| RDBMS-MIB::rdbmsSrvParamComment.893002000."AFF_SPROC".1 = STRING: Affinity start processor
		| $ snmpget -m Informix-MIB -On -c public -v 2c 101.0.200.200:5161 RDBMS-MIB::rdbmsSrvInfoStartupTime.893002000
		| .1.3.6.1.2.1.39.1.6.1.1.893002000 = STRING: 2013-4-22,12:6:39.0,+3:0
	
--------------------------------------------------------------
How use this Template?

    * Configure the zabbix agent on server where your Informix engine is running
      (please, check the zabbix manual/wiki for this)
    * After the Zabbix Agent configured and working with the Zabbix Server,
      add the line bellow at the end of /etc/zabbix/zabbix-agentd.conf :
        UserParameter=zabifx[*],/etc/zabbix/zabifx $1 $2
      Restart the zabbix agent.
    * Copy the script zabifx into the /etc/zabbix/ and add execute permission
      (chmod a+rx zabifx).
    * Link or create a shell script to set your Informix enviroment on
      /etc/zabbix/env.ifx.sh .
    * Test if the script is working typing : ./zabifx all $INFORMIXSERVER     
      (fell free to adapt the script to your environment)
      They should return something like :
        | /etc/zabbix>./zabifx all $INFORMIXSERVER
        | serverstatus|5
        | sessioncount|57
        | activesessioncount|1
        | topsessioncount|
        | llogcurrent|651608
        | llogwithoutbkp|1
        | llogwithoutbkpperc|0.25
        | rssservers|0
        | rssbacklog|0
        | rssconnactive|0
        | version|IBM Informix Dynamic Server Version 11.50.FC9
        | uptime|ZBX_NOTSUPPORTED
    * Start the Informix SNMP service
    * On Zabbix Server, with admin user, import the template :
      go to Configuration -> Templates -> Import (button, top right of screen)
    * On Host configurations, locate your host, and link the template with it.
	  (The host must have a SNMP interface configured, if not, configure it)
	  Save and done!
      You need to wait the discovery run (the default interval for this
      template is 2 hours) then check the lastest data for your host if it start
      to collect the data.     
      On "lastest data" page, should appear sessions like :
        | Informix Database (6 Items)
        | Informix Database - cluster (3 Items)
        | Informix Database - I/O (14 Items)
        | Informix Database - profile (35 Items)
        | Informix Database - sessions (5 Items)
       
--------------------------------------------------------------
Some details about this template
    * The discovery time is configured to 7200 seconds (= 2hours)
      This means new itens will be discovered or lost each 2 hours.
	  TIP: To speed up your first discovery or any changes into discovery 
	       items/triggers/graphs, you can change the interval parameter
	       to 30 seconds, wait 1 minute and check your "lastest data" and your
		   host items/triggers/graphs. If everything is OK, just back the 
		   interval to 7200 or any other value you desire.
    * The items are explict configured with port 5161.
      If you need to change this, I strong recommend to change this on
      .xml file before import the template, since there is no option to
      "mass update" for discovery items.
      And change into "Informix Instances" discovery too.
    * There are 2 items disabled by default (I don't consider them necessary
      on day-by-day)
    * Triggers for : Logical log without backup, Disk out space (when occur 
	  error -131),  RSS sync/connection, Sessions in lock, SNMP service down, 
	  Instance down.
    * Graphs for : Disk, General, Logical Logs, Memory usage, Network,
      RSS, Sessions and throughtput
     
   
--------------------------------------------------------------
Limitations / attention / caution:
* The template is configured to use the 5161 port for the SNMP Master Agent.
  If you plan use the default port 161 or other, before import the template
  edit the .xml and replace the string "<port>5161</port>" with the port you
  desire.

* When the engine goes down, the Informix SNMP sub-agent  (v11.50) stop to send 
  the Instance/Application status. 
  I consider this a bug, but to workaround this I get the instance status with 
  zabifx script where work well.

* Can't monitor dbspaces with Zabbix 2.0.5 (since it don't parse subitems correctly)
  Already exists a solution/patch for this, but I not apply or test since isn't 
  oficcially released yet:   https://support.zabbix.com/browse/ZBX-3449

* Zabbix triggers don't have dependecies since isn't allowed for discovered triggers

* Not have screens, since Zabbix 2.0.5 not allow create screens with discovered/prototypes items