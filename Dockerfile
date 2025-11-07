FROM eclipse-temurin:25-jdk

EXPOSE 8080

COPY target/spring-petclinic-*.jar spring-petclinic.jar

ENTRYPOINT ["java", "-jar", "/spring-petclinic.jar"]
