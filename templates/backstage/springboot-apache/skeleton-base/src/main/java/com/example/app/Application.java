package com.example.app;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
{% if values.useSpringWeb %}
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
{% endif %}

@SpringBootApplication
public class Application {
  public static void main(String[] args) {
    SpringApplication.run(Application.class, args);
  }
}
{% if values.useSpringWeb %}
@RestController
class HelloController {
  @GetMapping("/api/hello")
  public String hello() {
    return "hello from spring boot";
  }
}
{% endif %}
