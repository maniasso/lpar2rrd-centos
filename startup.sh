#!/bin/bash -x

if [ -f /firstrun ]; then
	# remote syslog server to docker host
	SYSLOG=`netstat -rn|grep ^0.0.0.0|awk '{print $2}'`
	echo "*.* @$SYSLOG" >> /etc/rsyslog.conf

	# Start syslog server to see something
	# /usr/sbin/rsyslogd

	echo "Running for first time.. need to configure..."
	/usr/libexec/httpd-ssl-gencerts

#	ln -s /etc/apache2/sites-available/*.conf /etc/apache2/conf.d/

#	cat <<EOF > /etc/apache2/conf.d/mod_cgi.conf
#<IfModule !mpm_prefork_module>
#  LoadModule cgid_module modules/mod_cgid.so
#</IfModule>
#  <IfModule mpm_prefork_module>
#  LoadModule cgi_module modules/mod_cgi.so
#</IfModule>
#EOF

	# RRDp module not found, move it
	mv /usr/share/vendor_perl/RRDp.pm  /usr/share/perl5/vendor_perl/

	# Generate Host keys
	ssh-keygen -A

	# setup products
        if [ -d "/home/lpar2rrd/lpar2rrd/bin" ]; then
            ITYPE="update.sh"
        else
            ITYPE="install.sh"
        fi
        chown lpar2rrd:lpar2rrd /home/lpar2rrd/lpar2rrd
        chown lpar2rrd:lpar2rrd  /home/lpar2rrd/stor2rrd
        cd /home/lpar2rrd; tar xvf lpar2rrd-$LPAR_VER.tar
        cd /home/stor2rrd; tar xvf stor2rrd-$STOR_VER.tar
        chmod 755  /home/lpar2rrd
	su - lpar2rrd -c "cd /home/lpar2rrd/lpar2rrd-$LPAR_VER/; yes '' | ./$ITYPE"
	rm -r /home/lpar2rrd/lpar2rrd-$LPAR_VER
	su - lpar2rrd -c "cd /home/stor2rrd/stor2rrd-$STOR_VER/; yes '' | ./$ITYPE"
	rm -r /home/stor2rrd/stor2rrd-$STOR_VER

	# enable LPAR2RRD daemon on default port (8162)
	sed -i "s/LPAR2RRD_AGENT_DAEMON\=0/LPAR2RRD_AGENT_DAEMON\=1/g" /home/lpar2rrd/lpar2rrd/etc/lpar2rrd.cfg
	# set DOCKER env var
	echo "export DOCKER=1" >> /home/lpar2rrd/lpar2rrd/etc/.magic

	if [[ -z "${TIMEZONE}" ]]; then
		# set default TZ to London, enable TZ change via GUI
		TIMEZONE="Europe/London"
	fi
	echo "${TIMEZONE}" > /etc/timezone
	chmod 666 /etc/timezone
	ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

	# copy .htaccess files for ACL
	cp -p /home/lpar2rrd/lpar2rrd/html/.htaccess /home/lpar2rrd/lpar2rrd/www
	cp -p /home/lpar2rrd/lpar2rrd/html/.htaccess /home/lpar2rrd/lpar2rrd/lpar2rrd-cgi

	cp -p /home/stor2rrd/stor2rrd/html/.htaccess /home/stor2rrd/stor2rrd/www
	cp -p /home/stor2rrd/stor2rrd/html/.htaccess /home/stor2rrd/stor2rrd/stor2rrd-cgi

        # initialize lpar2rrd's crontab
        crontab -u lpar2rrd /var/spool/cron/crontabs/lpar2rrd

	# clean up
	rm /firstrun
fi

# Sometimes with un unclean exit the rsyslog pid doesn't get removed and refuses to start
if [ -f /var/run/rsyslogd.pid ]; then
	rm /var/run/rsyslogd.pid
fi

# Start supervisor to start the services
/usr/bin/supervisord -c /etc/supervisord.conf -l /var/log/supervisor.log -j /var/run/supervisord.pid
