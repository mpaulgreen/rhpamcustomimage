FROM registry.redhat.io/rhpam-7/rhpam-kieserver-rhel8:7.9.0
LABEL   name="Microsoft SQL Server JDBC Driver" \
        version="7.2.2.jre11"

# Copy the extension API artifact
COPY ./GetTasksCustomAPI-1.0.jar /opt/eap/standalone/deployments/ROOT.war/WEB-INF/lib/

COPY ./build /extensions
RUN bash -x /extensions/install.sh /extensions