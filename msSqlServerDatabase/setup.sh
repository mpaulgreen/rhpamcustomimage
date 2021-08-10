prepareFiles() {
    export DRIVERS DRIVER_NAME DRIVER_MODULE DRIVER_CLASS DRIVER_XA_CLASS DRIVER_DIR DRIVER_JDBC_ARTIFACT_NAME \
    DATABASE_TYPE VERSION EXTENSIONS_INSTALL_DIR
    env | egrep "DRIVER|DATABASE"
    rm -rf build
    mkdir -p build/modules
    mkdir -p build/modules/${DRIVER_DIR}
    cp templates/install.sh build
    cat templates/base-install.properties | envsubst > build/install.properties
    if [ "${PIPESTATUS[0]}" -eq 0 ]; then echo "file install.properties successfully generated."; else echo "failed to create install.properties"; fi
    cat templates/base-Dockerfile | envsubst > ./Dockerfile
    if [ "${PIPESTATUS[0]}" -eq 0 ]; then echo "file Dockerfile successfully generated."; else echo "failed to create Dockerfile"; fi
    cat templates/${DRIVER_DIR}/base-module.xml | envsubst > build/modules/${DRIVER_DIR}/module.xml
    if [ "${PIPESTATUS[0]}" -eq 0 ]; then echo "file module.xml successfully generated."; else echo "failed to create module.xml"; fi

    curl -S -o build/modules/${DRIVER_DIR}/${DRIVER_JDBC_ARTIFACT_NAME} \
      https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/${VERSION}/${DRIVER_JDBC_ARTIFACT_NAME}
}

DATABASE_TYPE="mssql"
VERSION="7.2.2.jre11"
DRIVERS="MSSQL"
DRIVER_NAME="mssql"
DRIVER_MODULE="com.microsoft"
DRIVER_CLASS="com.microsoft.sqlserver.jdbc.SQLServerDriver"
DRIVER_XA_CLASS="com.microsoft.sqlserver.jdbc.SQLServerXADataSource"

# base path is $JBOSS_HOME/modules
DRIVER_DIR="com/microsoft/main"
DRIVER_JDBC_ARTIFACT_NAME="mssql-jdbc-${VERSION}.jar"

EXTENSIONS_INSTALL_DIR=/extensions

prepareFiles

