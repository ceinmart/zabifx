2019-06-14
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
 10/oct/2018 - Rewrite to work only with "onstat" , without SNMP service.
  

Index
- About this Template_Informix
- Limitations / attention / caution:
--------------------------------------------------------------
About this Template_Informix

    This template was created , tested and used successfully
    on Zabbix 4.2.1 (rpm opensuse 15.0 ) monitoring multiple 
    IBM Informix v12.10 FC12 running over Red Hat 7.4 .
   
    They objective was monitor Informix instances.
    This template are 100% dependent of the shell script zabifx.sh 
    were this script use the "onstat" for all collect.

    This template+script able to discovery all instances + dbspaces .

--------------------------------------------------------------
How use this Template?

    * Configure the zabbix agent on server where your Informix engine is running
      (please, check the zabbix manual/wiki for this)
    * Add the zabbix user to informix group to allow access onstat : 
      $ usermod zabbix -G informix -a 
    * Clone this GIT repository 
      $ cd /etc/zabbix
      $ git clone https://github.com/ceinmart/zabifx.git zabifx.git
      A subfolder "zabifx.git" should be created with the scripts there. 
    * Add the content of zabifx.git/zabbix-agentd.conf to your current Zabbix Agent config
        cat zabifx.git/zabbix-agent.conf >> zabbix-agent.conf
    * Link the scripts
      $ cd /etc/zabbix
      $ ln -s zabifx.git/zabifx.sh  zabifx.sh
      $ ln -s zabifx.git/env.ifx.sh env.ifx.sh 
    * Link or create a shell script to allow set your Informix enviroment 
      /etc/zabbix/env.ifx.sh or /home/informix/env.ifx.sh .
    * Logged with zabbix user, test zabbix if the script is working :  
      $ /etc/zabbix/zabifx.sh instances - 
      They should return something like :
        | {"data":[{ "{#IFXSERVER}":"ifxvserv1","{#IFXSERVERSTATUS}":"Up","{#IFXMSGPATH}":"/opt/informix/tmp/ifxserv1.log"}]}
    * Restart the zabbix agent.
      $ systemctl restart zabbix-agentd
    * On Zabbix Server, with admin user, import the template :
      go to Configuration -> Templates -> Import (button, top right of screen)
    * On Host configurations, locate your host, and link the template with it.
      You need to wait the discovery run (the default interval for this
      template is 2 hours) or you can force selecting the discovery item and click to "check now" button. 
      On "lastest data" page, should appear sessions like :
		| Informix Database (5 Items)
		| Informix Database - cluster (3 Items)
		| Informix Database - dbspaces (164 Items)
		| Informix Database - I/O (4 Items)
		| Informix Database - Memory (10 Items)
		| Informix Database - profile (21 Items)
		| Informix Database - sessions (4 Items)
		| Informix Database - VPs (13 Items)

       

