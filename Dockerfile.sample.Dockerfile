# Note: This image must be running debian jessie, which as of 1/25/18 is what python:3 runs
#       The lines that install microsoft sql server odbc driver refer to debian 8 (jessie)
#       If that changes, update accordingly
FROM python:3
RUN mkdir /pyodbc-sqlserver
COPY dockerfiles /pyodbc-sqlserver/dockerfiles
WORKDIR /pyodbc-sqlserver
RUN cp dockerfiles/apt.conf /etc/apt/apt.conf
RUN apt-get update
# https://serverfault.com/a/662037
RUN export DEBIAN_FRONTEND=noninteractive
RUN apt-get install locales
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
RUN locale-gen
# Make sure to install apt-transport-https otherwise you get this error:
# E: The method driver /usr/lib/apt/methods/https could not be found.
# https://askubuntu.com/a/211531
# For kerberos, install packages "krb5-user" and "ntp" also
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y git unixodbc-dev curl apt-transport-https 
# https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server
RUN http_proxy=http://proxy.site.com:9999 https_proxy=http://proxy.site.com:9999 curl -v https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN http_proxy=http://proxy.site.com:9999 https_proxy=http://proxy.site.com:9999 curl -v https://packages.microsoft.com/config/debian/8/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update
RUN ACCEPT_EULA=Y apt-get install msodbcsql
# git setup
RUN git config --global http.proxy http://proxy-chain.intel.com:911
RUN git config --global https.proxy http://proxy-chain.intel.com:911
RUN git config --global url."https://".insteadOf git://
COPY requirements.txt /pyodbc-sqlserver/requirements.txt
RUN http_proxy=http://proxy.site.com:9999 \
https_proxy=http://proxy.site.com:9999 \
pip install -r requirements.txt
COPY . /pyodbc-sqlserver/
# md5sum everything. Docker doesn't always catch our code changes.
RUN find . -type f -name "*" -exec md5sum {} + | awk '{print $1}' | sort | md5sum
RUN yamllint -d .yamllint.conf.yml .
WORKDIR /pyodbc-sqlserver/
RUN pip install -e .
RUN flake8 .
# Kerberos is not supported by this code currently, but may be in the future.
# If you want the IMAGE to have a keytab built in, uncomment these.
# Note that you need to put the keytab in the dockerfiles/ folder.
# RUN cp dockerfiles/krb5.keytab /etc/krb5.keytab
# RUN kinit some_domain_username_here -k -t /etc/krb5.keytab
CMD /usr/bin/env python /pyodbc-sqlserver/example.py