FROM eclipse-temurin:${{ values.javaVersion }}-jre

WORKDIR /app

# Normalized by workflow from target/*.jar or target/*.war
COPY target/app-runtime.jar /app/app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
