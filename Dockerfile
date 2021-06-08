#!/usr/bin/docker build .
#
# VERSION               1.0

FROM       centos:latest
MAINTAINER jirka@dutka.net

ENV HOSTNAME XoruX
ENV VI_IMAGE 1

# create file to see if this is the firstrun when started
RUN touch /firstrun

RUN  yum install -y perl rrdtool rrdtool-perl httpd mod_ssl

RUN yum -y install epel-release

RUN yum -y install perl-TimeDate perl-XML-Simple perl-XML-SAX perl-XML-LibXML perl-Env perl-CGI perl-Data-Dumper perl-LWP-Protocol-https perl-libwww-perl perl-Time-HiRes 

RUN yum -y  install ed bc libxml2 httpd sudo supervisor cronie crontabs rsyslog openssh-server net-tools gzip which

RUN yum -y clean all

# setup default user
RUN groupadd  lpar2rrd 
RUN adduser  lpar2rrd -g lpar2rrd -u 1005 -s /bin/bash
RUN echo 'lpar2rrd:xorux4you' | chpasswd
RUN echo '%lpar2rrd ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN mkdir /home/stor2rrd \
    && mkdir /home/lpar2rrd/stor2rrd \
    && ln -s /home/lpar2rrd/stor2rrd /home/stor2rrd \
    && chown lpar2rrd /home/lpar2rrd/stor2rrd

# configure Apache
COPY configs/httpd.conf  /etc/httpd/conf/httpd.conf


# add product installations
ENV LPAR_VER_MAJ "7.00"
ENV LPAR_VER_MIN ""
ENV LPAR_SF_DIR "7.00"
ENV STOR_VER_MAJ "7.00"
ENV STOR_VER_MIN ""
ENV STOR_SF_DIR "7.00"

ENV LPAR_VER "$LPAR_VER_MAJ$LPAR_VER_MIN"
ENV STOR_VER "$STOR_VER_MAJ$STOR_VER_MIN"

# expose ports for SSH, HTTP, HTTPS and LPAR2RRD daemon
EXPOSE 22 80 443 8162

COPY configs/crontab /var/spool/cron/crontabs/lpar2rrd
RUN chmod 640 /var/spool/cron/crontabs/lpar2rrd && chown lpar2rrd:lpar2rrd /var/spool/cron/crontabs/lpar2rrd

COPY tz.pl /var/www/cgi-bin/tz.pl
RUN chmod +x /var/www/cgi-bin/tz.pl

# download tarballs from SF
# ADD http://downloads.sourceforge.net/project/lpar2rrd/lpar2rrd/$LPAR_SF_DIR/lpar2rrd-$LPAR_VER.tar /home/lpar2rrd/
# ADD http://downloads.sourceforge.net/project/stor2rrd/stor2rrd/$STOR_SF_DIR/stor2rrd-$STOR_VER.tar /home/stor2rrd/

# download tarballs from official website
ADD https://lpar2rrd.com/download-static/lpar2rrd/lpar2rrd-$LPAR_VER.tar /home/lpar2rrd/
ADD https://stor2rrd.com/download-static/stor2rrd/stor2rrd-$STOR_VER.tar /home/stor2rrd/

# extract tarballs
WORKDIR /home/lpar2rrd
RUN tar xvf lpar2rrd-$LPAR_VER.tar

WORKDIR /home/stor2rrd
RUN tar xvf stor2rrd-$STOR_VER.tar

COPY supervisord.conf /etc/
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

RUN mkdir -p /home/lpar2rrd/lpar2rrd /home/stor2rrd/stor2rrd
RUN chown -R lpar2rrd /home/lpar2rrd /home/stor2rrd
VOLUME [ "/home/lpar2rrd/lpar2rrd", "/home/stor2rrd/stor2rrd" ]

ENTRYPOINT [ "/startup.sh" ]

