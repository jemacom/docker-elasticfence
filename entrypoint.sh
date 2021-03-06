#!/bin/bash

set -e

if [ ! -z "$ELASTICSEARCH_URL" ]; then
        : ${ELASTICSEARCH_URL:='http://elasticsearch:9200'}
        sed -ri "s!^(\#\s*)?(elasticsearch\.url:).*!\2 '$ELASTICSEARCH_URL'!" /opt/kibi/config/kibi.yml
        # Remove Auth Plugin
        /opt/kibi/bin/kibi plugin -r kibana-auth-plugin
        echo "Remote Server! No ES Logs available." > /var/log/elasticsearch/nolog.log
else
        echo "No ES URL parameter, starting local instance... "
        # Patch demo ES to listen to all interfaces using elasticfence authentication
        echo "network.host: 0.0.0.0" >> /etc/elasticsearch/elasticsearch.yml
        echo "elasticfence.disabled: false" >> /etc/elasticsearch/elasticsearch.yml
        echo "elasticfence.root.password: $ELASTICSEARCH_PASS" >> /etc/elasticsearch/elasticsearch.yml 
        echo "elasticfence.whitelist: [\"127.0.0.1\"]" >> /etc/elasticsearch/elasticsearch.yml 
        service elasticsearch start
        sleep 8
        # create admin user 
        curl "127.0.0.1:9200/_httpuserauth?mode=adduser&username=$ELASTICSEARCH_USER&password=$ELASTICSEARCH_PASS" -u "root:$ELASTICSEARCH_PASS"
        curl "127.0.0.1:9200/_httpuserauth?mode=updateindex&username=$ELASTICSEARCH_USER&index=/.*" -u "root:$ELASTICSEARCH_PASS"
fi

# Patch demo kibi to use standard ES port
perl -p -i -e "s/9220/9200/" /opt/kibi/config/kibi.yml
perl -p -i -e "s/localhost/0.0.0.0/" /opt/kibi/config/kibi.yml
perl -p -i -e "s/default_dashboard_title: Articles//" /opt/kibi/config/kibi.yml

# Start Kibi
/etc/init.d/kibi start
tail -f /var/log/elasticsearch/*.log
