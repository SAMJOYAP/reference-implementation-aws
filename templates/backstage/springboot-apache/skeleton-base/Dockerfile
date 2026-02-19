FROM eclipse-temurin:${{ values.javaVersion }}-jre

WORKDIR /app
COPY build/libs/app-runtime.jar /app/app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
