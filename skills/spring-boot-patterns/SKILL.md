---
name: spring-boot-patterns
description: Spring Boot layering, transaction boundary, REST client, and security conventions. Use when implementing or reviewing any service, controller, or repository-layer code.
---

## Layering

Controller → Service (or Command) → Repository. Controllers do not contain business logic; they map requests/responses and delegate. Business rules live in the service/command layer. Repositories are persistence-only.

## Transaction boundaries

- `@Transactional` is applied at the **method level only** — never at the class level.
- Class-level `@Transactional` is an anti-pattern: it silently wraps every method (including helpers and void utilities), making it impossible to audit which operations actually need a transaction.
- Read-only operations use `@Transactional(readOnly = true)`.
- **Never make an external HTTP call or message publish inside a `@Transactional` scope.** Do the DB write first, let it commit, then make the external call. If the external call fails, apply compensating logic — rollback cannot cover a network call.

```java
// Correct — method-level, not class-level
@Transactional
public void createFoo(FooInput input) { ... }

@Transactional(readOnly = true)
public Foo findById(Long id) { ... }
```

## REST client

Prefer the declarative `@HttpExchange` interface backed by `RestClient` for new external integrations — it keeps the HTTP details in one place and is easier to test:

```java
@HttpExchange("/api/resource")
public interface ExternalServiceClient {

    @PostExchange
    ResponseDto create(@RequestBody RequestDto request);

    @GetExchange("/{id}")
    ResponseDto getById(@PathVariable String id);
}
```

Wire the proxy in a `@Configuration`:

```java
@Bean
public ExternalServiceClient externalServiceClient(RestClient.Builder builder) {
    RestClient client = builder
        .baseUrl(properties.baseUrl())
        .build();
    return HttpServiceProxyFactory
        .builderFor(RestClientAdapter.create(client))
        .build()
        .createClient(ExternalServiceClient.class);
}
```

Use the imperative `RestClient` API only when you need per-request logic (e.g., injecting an OAuth2 token per call via an interceptor) that the declarative form can't accommodate. Never use `RestTemplate`.

## Security

Keep security configuration IDP-agnostic. Use Spring Security abstractions — do not hard-code provider class names (Keycloak, Authentik, Okta, etc.) in production code. The issuer URI and claim mappings belong in `application.yml`, not in Java.

Standard stateless resource-server pattern:

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/**").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()));
        return http.build();
    }
}
```

Use `@EnableMethodSecurity` and `@PreAuthorize` for fine-grained method-level checks. Extract role/authority mapping logic into a dedicated converter class rather than inlining it in `SecurityConfig`.

## Error handling

Exceptions map to HTTP responses via a centralized `@ControllerAdvice` — don't catch-and-translate inside controllers or services. Use domain-specific exception types with clear names (e.g., `ResourceNotFoundException`, `DuplicateResourceException`) that the advice maps to the correct status codes.

## Dependency injection

Constructor injection only — no field injection (`@Autowired` on fields). If using Lombok, `@RequiredArgsConstructor` is fine. No circular service dependencies; if one appears it signals a domain boundary problem, not a `@Lazy` fix.

---

## Codebase conventions

> This section is populated by `/init-context` for existing projects. It captures project-specific implementations of the patterns above (e.g., a shared Command abstraction, custom exception types, specific BOM libraries, REST client interceptors, security claim mapping). For new projects, add conventions here as they are established.
