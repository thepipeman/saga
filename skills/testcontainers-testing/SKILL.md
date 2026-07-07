---
name: testcontainers-testing
description: Testcontainers and unit/integration test conventions. Use whenever writing tests as part of an implementation.
---

## Unit vs. integration

- Service/command business logic gets unit tests with mocked dependencies — no container, fast feedback.
- Repository-layer (jOOQ) code gets integration tests against a real Postgres via Testcontainers — jOOQ-generated queries must run against real Postgres semantics, not mocks.
- Full HTTP-level flows (controller → service → repository) use `@SpringBootTest` with the real application context and a running container.

## Testcontainers setup

Reuse a single Postgres container across the module by using the singleton pattern — one static instance per module, not one per test class:

```java
public final class AppPostgresContainer extends PostgreSQLContainer<AppPostgresContainer> {

    private static AppPostgresContainer instance;

    private AppPostgresContainer() {
        super("postgres:17-alpine");
    }

    public static AppPostgresContainer getInstance() {
        if (instance == null) instance = new AppPostgresContainer();
        return instance;
    }
}
```

Wire it into a base integration test class that all `@SpringBootTest` tests extend:

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
public abstract class BaseIntegrationTest {

    @Container
    protected static final PostgreSQLContainer<?> db = AppPostgresContainer.getInstance();

    @DynamicPropertySource
    static void datasourceProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", db::getJdbcUrl);
        registry.add("spring.datasource.username", db::getUsername);
        registry.add("spring.datasource.password", db::getPassword);
    }

    @BeforeAll
    static void startContainer() { db.start(); }

    @AfterAll
    static void stopContainer()  { db.stop(); }
}
```

Migrations run against the test container the same way they run in real environments (same Flyway/Liquibase config) — do not hand-roll a separate test schema.

## Repository-layer tests

Use `@JooqTest` (not `@SpringBootTest`) for isolated repository tests when you want Flyway + jOOQ without the full application context. Prevent Spring from replacing the datasource with an embedded one:

```java
@JooqTest(properties = {"spring.test.database.replace=none"})
@ActiveProfiles("test")
class FooRepositoryTest {

    @Autowired DSLContext dsl;
    FooRepository repo;

    @BeforeEach void setUp() { repo = new FooRepository(dsl); }

    @Test void shouldCreateFoo() { ... }
}
```

## Security in integration tests

For `@SpringBootTest` tests that hit secured endpoints, override the `JwtDecoder` bean with a `@TestConfiguration` that issues HMAC-signed tokens locally — this removes the IDP from the test dependency chain:

```java
@TestConfiguration
class TestSecurityConfig {
    @Bean @Primary
    JwtDecoder jwtDecoder() {
        SecretKeySpec key = new SecretKeySpec("test-key-long-enough".getBytes(UTF_8), "HmacSHA256");
        return NimbusJwtDecoder.withSecretKey(key).build();
    }
}
```

Mock any OAuth2 client registration beans that would try to contact a real auth server:

```java
@MockitoBean
ClientRegistrationRepository clientRegistrationRepository;
```

## jOOQ codegen in tests

If jOOQ sources are generated at build time against a Testcontainers instance (not committed), ensure the codegen step runs before `compile` in the build lifecycle so generated classes are available to production and test code. Generated sources must not be committed.

## What "adequately tested" means

- Every public service/command method: happy path, at least one validation/error path, and any edge case named in the design doc's acceptance criteria.
- Idempotency-sensitive paths: include a "call it twice" test asserting the correct idempotent outcome.
- Transaction-boundary logic around external calls: force the external call to fail and assert the DB state is consistent (the write should not have persisted, or compensating logic should have run).

---

## Codebase conventions

> This section is populated by `/init-context` for existing projects. It captures project-specific details: base test class name and location, container class name, Postgres image version in use, active test profile(s), HTTP testing library (RestAssured, MockMvc, etc.), test JWT provider implementation, and any shared test data setup patterns (`@Sql`, fixtures, etc.).
