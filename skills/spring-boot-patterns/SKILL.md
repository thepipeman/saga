---
name: spring-boot-patterns
description: Spring Boot 4 layering, transaction boundary, REST client, API versioning, and security conventions. Use when implementing or reviewing any service, controller, or repository-layer code.
---

## Version baseline

**Java 25 and Spring Boot 4.x — always, on every project.** Spring Framework 7, Spring Security 7, Jakarta EE 11, GraalVM 25+ for native images. This is a floor, not a target to migrate toward: generate Java 25 code using records, sealed types, pattern matching, and virtual threads by default. Pre-21 idioms in new code are a defect.

If you find yourself in a project that is still on Boot 3.x or an older JDK, say so plainly and stop rather than silently downgrading the code you generate — the fix is to upgrade the project, and that's a decision for the human, not something to work around one file at a time.

See `references/java-25.md` for the language-level and virtual-thread guidance.

Do not generate Boot 3.x-era code. The renames that most often trip up generated code:

| Boot 4 | Replaced |
|---|---|
| `spring-boot-starter-webmvc` | `spring-boot-starter-web` |
| `spring-boot-starter-webservices` | `spring-boot-starter-web-services` |
| `spring-boot-starter-security-oauth2-*` | `spring-boot-starter-oauth2-*` |
| `@MockitoBean` / `@MockitoSpyBean` | `@MockBean` / `@SpyBean` (removed) |
| `org.jspecify.annotations.@Nullable` | `org.springframework.lang.@Nullable` (deprecated) |
| `hibernate-processor` | `hibernate-jpamodelgen` |
| `spring.persistence.exceptiontranslation.enabled` | `spring.dao.exceptiontranslation.enabled` |

Undertow, Spock integration, and the embedded uber-jar launch scripts were removed outright. Anything deprecated in 3.x is gone — don't reach for it.

## Layering

Controller → Service (or Command) → Repository. Controllers do not contain business logic; they map requests/responses and delegate. Business rules live in the service/command layer. Repositories are persistence-only.

Controllers accept and return DTOs — records, not entities or generated database records. For the repository layer itself, follow whichever persistence skill matches this project's stack: `spring-data-jpa` or `jooq-conventions`. `.claude/context/PATTERNS.md` records which one was chosen.

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

Register it with `@ImportHttpServices` (Framework 7) rather than hand-building an `HttpServiceProxyFactory`. The annotation is repeatable, groups clients by name, and defaults to a `RestClient`-backed proxy:

```java
@Configuration
@ImportHttpServices(group = "billing", types = ExternalServiceClient.class)
public class HttpClientConfig {

    @Bean
    RestClientHttpServiceGroupConfigurer billingClientConfigurer(BillingProperties properties) {
        return groups -> groups.filterByName("billing")
            .forEachClient((group, builder) -> builder.baseUrl(properties.baseUrl()));
    }
}
```

`basePackages` / `basePackageClasses` work in place of `types` when a group has many interfaces. Base URLs, timeouts, and default headers are configurable per group under `spring.http.client.service.<group>.*` — keep them in `application.yml`, not in Java.

Use the imperative `RestClient` API only when you need per-request logic the declarative form can't accommodate. For OAuth2, that's usually not a reason to drop down: Spring Security 7 supports HTTP service groups directly and picks up a `@ClientRegistrationId` annotation on the `@HttpExchange` method.

Never use `RestTemplate`.

## API versioning

Framework 7 has first-class request-mapping versioning — don't hand-roll `/v1/` path prefixes or a custom header filter for a versioned contract:

```java
@Configuration
public class WebConfiguration implements WebMvcConfigurer {

    @Override
    public void configureApiVersioning(ApiVersionConfigurer configurer) {
        configurer.useRequestHeader("API-Version");
    }
}
```

```java
@GetMapping(path = "/{id}", version = "1.0")
public OrderV1 getV1(@PathVariable UUID id) { ... }

@GetMapping(path = "/{id}", version = "2.0")
public OrderV2 getV2(@PathVariable UUID id) { ... }
```

`useRequestParameter`, `usePathSegment`, and `useMediaTypeParameter` are the other built-in resolvers. Unsupported versions are rejected with `InvalidApiVersionException` (400). Configure an `ApiVersionDeprecationHandler` to emit `Deprecation`/`Sunset` headers when retiring a version.

## Null-safety

Framework 7 standardizes on JSpecify. Put `@NullMarked` on `package-info.java` so unannotated types are non-null by default, and annotate only genuinely nullable ones with `org.jspecify.annotations.@Nullable`:

```java
@NullMarked
package com.example.order;

import org.jspecify.annotations.NullMarked;
```

`org.springframework.lang.@Nullable`, `@NonNullApi`, and `@NonNullFields` are deprecated — don't introduce them.

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

Exceptions map to HTTP responses via a centralized `@RestControllerAdvice` — don't catch-and-translate inside controllers or services. Use domain-specific exception types with clear names (e.g. `ResourceNotFoundException`, `DuplicateResourceException`) that the advice maps to the correct status codes.

Return `ProblemDetail` (RFC 9457) rather than an ad-hoc error map, so every service in the estate produces the same error shape:

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundException.class)
    ProblemDetail handleNotFound(ResourceNotFoundException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        ProblemDetail problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setTitle("Validation failed");
        problem.setProperty("errors", ex.getBindingResult().getFieldErrors().stream()
            .collect(toMap(FieldError::getField, FieldError::getDefaultMessage, (a, b) -> a)));
        return problem;
    }
}
```

Extend `ResponseEntityExceptionHandler` when you want Spring's built-in handling of the standard MVC exceptions and only need to override a few. Never let a raw persistence exception reach the client — map `OptimisticLockingFailureException` to `409 Conflict` and `DataIntegrityViolationException` to `409` or `400`, and never surface the underlying constraint name in the response body.

Validate at the edge: `@Valid` on every `@RequestBody`, and constraints declared on the DTO record components rather than checked imperatively in the service.

## Dependency injection

Constructor injection only — no field injection (`@Autowired` on fields). If using Lombok, `@RequiredArgsConstructor` is fine. No circular service dependencies; if one appears it signals a domain boundary problem, not a `@Lazy` fix.

Note that Lombok's value is much reduced on Java 25 — records cover the DTO and value-object cases outright, so reach for Lombok only for `@RequiredArgsConstructor` and `@Slf4j` on components. Never put Lombok's `@Data` on a JPA entity (see the `spring-data-jpa` skill for why that specifically breaks).

## Javadoc and code comments

Javadoc is written for the next developer reading this class months from now, with no memory of how it came to exist. It carries only what the code itself can't:

- **Business context** — the problem this type or method solves, the rule it enforces, the invariant it protects.
- **Technical context and the decision behind it** — why it's built this way, and any non-obvious constraint (ordering, idempotency, concurrency, external-call boundaries).

**Be brief.** A one-line summary, plus a short `<p>` only when a decision is genuinely non-obvious. Past roughly six lines you are almost certainly restating the code or telling a story — cut it. Reserve real explanation for the rare hack or workaround that a reader would otherwise "fix". Skip Javadoc entirely where it would only restate the signature (trivial getters, self-evident DTO records, plain delegation); an accurate one-liner on the three methods carrying real business rules beats a docblock on every method. Inline comments explain *why*, never narrate *what*.

**Document the current state, not the change that produced it.** No "now", "previously", "unlike before", "used to", "this was refactored to" — the reader sees only today's code, and history lives in git. Mention a prior state only when it is load-bearing (a workaround for an external bug, or a constraint someone would innocently undo), and then state the constraint, not the story.

**Never reference how the code was produced.** No design docs, specs, instruction or requirement files, implementation notes, review phases, workflow steps, AI, agents, models, prompts, or `.claude/` paths. A future reader has none of that context, and a comment pointing at an artifact they can't find is worse than no comment.

```java
// Wrong — narrates the change, points at a process artifact, buries the rule in an essay
/**
 * This test now shares its Spring context with every other class extending
 * {@link AbstractIntegrationTest}, unlike before when it hand-rolled its own —
 * see the approved design doc (.claude/design-drafts/refunds-design.md). The rows
 * persisted by a real initiate-then-verify flow are cleaned up here, in FK-safe
 * order, or they'd linger and trip other tests' own table-wide cleanup, e.g.
 * CareSessionPersistenceIntegrationTest's careSessionRepository.deleteAll(), which
 * fails on authentication_flow_care_session_id_fkey if this test's flow row is ...
 */

// Right — the constraint, stated once
/**
 * Deletes persisted rows in FK-safe order; the shared context leaks them into other
 * tests' table-wide deletes otherwise.
 */

// Right — business context plus the decision and its reason
/**
 * Issues a refund against a settled payment.
 *
 * <p>Capped at the settled amount: the provider rejects over-refunds asynchronously
 * with no correlation id, so the cap cannot be enforced downstream.
 *
 * @param amount refund amount; must not exceed the settled amount
 * @throws RefundExceedsSettlementException if the cap is breached
 */
```

## Reference material

| Topic | Reference | Load when |
|---|---|---|
| Java 25 | `references/java-25.md` | Choosing between records/sealed types/pattern matching, enabling or tuning virtual threads, replacing `ThreadLocal` with scoped values, deciding whether a preview API is safe to use |

For persistence, load the skill matching this project's stack — `spring-data-jpa` or `jooq-conventions`.

---

## Codebase conventions

Read `.claude/context/conventions/spring-boot-patterns.md` if it exists in the current project. That file is the authoritative project-specific override for this skill and takes precedence over every generic pattern documented above. If the file is absent, apply the generic guidance in this skill as written.
