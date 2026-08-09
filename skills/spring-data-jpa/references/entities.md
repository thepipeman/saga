# Entity mapping

Targets Jakarta Persistence 3.2 / Hibernate 7.1 on PostgreSQL. Read alongside the `postgres-migrations` skill — the entity and the migration must be written together, and the migration is the source of truth.

## Table and column naming

Always name the table and every column explicitly. Implicit naming makes the entity's mapping depend on a naming strategy bean that a future dependency bump can change underneath you.

```java
@Entity
@Table(name = "orders", schema = "sales")
public class Order {

    @Column(name = "customer_reference", nullable = false, length = 64)
    private String customerReference;
}
```

Mirror the migration's nullability in `@Column(nullable = ...)`. It doesn't create the constraint — `ddl-auto: validate` only checks it — but it documents intent and makes a drift between entity and schema fail at startup rather than at the first insert.

## Identifiers

**Prefer `SEQUENCE` over `IDENTITY` for generated numeric keys.** `IDENTITY` forces Hibernate to execute the insert immediately on `persist()` to obtain the key, which disables JDBC batching entirely — every row becomes its own round trip.

```java
@Id
@GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "order_seq")
@SequenceGenerator(name = "order_seq", sequenceName = "sales.order_id_seq", allocationSize = 50)
private Long id;
```

`allocationSize` must match the `INCREMENT BY` of the actual Postgres sequence. A mismatch (the classic case: `allocationSize = 50` against a default `INCREMENT BY 1` sequence) produces silent key collisions between application instances.

**For UUID keys, assign in the constructor rather than letting the database generate.** Knowing the id before the insert makes the aggregate usable — and testable — before it is persisted:

```java
@Id
@Column(name = "id", nullable = false, updatable = false)
private UUID id;

protected Order() { }  // JPA requires a no-arg constructor

public Order(UUID id, String customerReference) {
    this.id = Objects.requireNonNull(id);
    this.customerReference = customerReference;
}
```

Random v4 UUIDs fragment B-tree indexes because inserts land at random positions. On a high-insert table prefer a time-ordered UUID (v7) so new rows append to the right edge of the index.

## equals and hashCode

Entities are mutable, live across the detached/managed boundary, and may be put in a `Set` before they have a database-assigned id. That breaks the naive implementations.

```java
@Override
public boolean equals(Object other) {
    if (this == other) return true;
    if (!(other instanceof Order that)) return false;
    return id != null && id.equals(that.id);
}

@Override
public int hashCode() {
    return getClass().hashCode();   // constant — stable across the id being assigned
}
```

A constant `hashCode` looks wrong but is the correct trade-off: it keeps the contract intact when an entity is added to a `HashSet` before `persist()` assigns the id. Use `instanceof` rather than `getClass() != other.getClass()` so Hibernate proxies compare equal to their targets.

**Never put Lombok's `@Data` or `@EqualsAndHashCode` on an entity.** They generate field-based equality that touches every field, including lazy associations — which triggers loads, and on a bidirectional association, infinite recursion. Same reason `@ToString` must exclude associations.

## Enums

```java
@Enumerated(EnumType.STRING)
@Column(name = "status", nullable = false, length = 32)
private OrderStatus status;
```

`EnumType.ORDINAL` is the default and is unsafe — reordering or inserting a constant silently remaps every existing row. Always declare `STRING`.

When the database column holds a short code rather than the constant name, Jakarta Persistence 3.2's `@EnumeratedValue` maps it without a converter:

```java
public enum OrderStatus {
    PENDING("P"), SHIPPED("S"), CANCELLED("C");

    @EnumeratedValue
    private final String code;

    OrderStatus(String code) { this.code = code; }
}
```

## Associations

Every association is `LAZY`. `@ManyToOne` and `@OneToOne` default to `EAGER` and must be overridden:

```java
@ManyToOne(fetch = FetchType.LAZY, optional = false)
@JoinColumn(name = "customer_id", nullable = false)
private Customer customer;

@OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
private List<OrderItem> items = new ArrayList<>();
```

Rules that follow from this:

- **`mappedBy` marks the inverse side.** The side holding the foreign key owns the relationship; the other side is read-only for persistence purposes. Setting only the inverse side and expecting a write to happen is one of the most common JPA bugs.
- **Maintain both sides through helper methods** so the in-memory object graph stays consistent with what will be flushed:

  ```java
  public void addItem(OrderItem item) {
      items.add(item);
      item.setOrder(this);
  }
  ```

- **`cascade = ALL` + `orphanRemoval = true` belongs only on a true composition** — where the child has no independent lifecycle (order → order items). Never cascade `REMOVE` from a `@ManyToOne`; deleting an order item must not delete the order.
- **Don't map a collection you never traverse as an aggregate.** If a `Customer` has 100k orders, `@OneToMany List<Order>` is a loaded footgun — query `OrderRepository` with a `Pageable` instead. Map the association only when the collection is bounded and genuinely part of the aggregate.
- **`@OneToOne` on the inverse side cannot be lazy** without bytecode enhancement — Hibernate must query to know whether to populate the field with `null` or a proxy. Prefer putting the FK on the side you load most, or model it as `@ManyToOne` with a unique constraint.

## Embeddables

Value objects with no identity of their own map as `@Embeddable`, which keeps the columns on the owning table while giving the domain a real type:

```java
@Embeddable
public record Money(
    @Column(name = "amount", nullable = false) BigDecimal amount,
    @Column(name = "currency", nullable = false, length = 3) String currency
) { }
```

Records are valid `@Embeddable` types in Jakarta Persistence 3.2. Records are **not** valid `@Entity` types — entities need a no-arg constructor and mutable state for dirty checking.

## Optimistic locking

Any entity that can be modified by two concurrent requests carries a `@Version` column. This is the cheap fix for lost updates and it costs one integer column:

```java
@Version
@Column(name = "version", nullable = false)
private long version;
```

Concurrent modification then surfaces as `OptimisticLockingFailureException`, which the `@ControllerAdvice` maps to `409 Conflict`. Reach for pessimistic locking (`@Lock(LockModeType.PESSIMISTIC_WRITE)`) only when the contention is genuinely high and a retry loop isn't acceptable — it holds a row lock for the transaction's duration.

## Auditing

```java
@Configuration
@EnableJpaAuditing(auditorAwareRef = "auditorAware")
class JpaAuditingConfig {

    @Bean
    AuditorAware<String> auditorAware(/* security context accessor */) {
        return () -> Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
            .map(Authentication::getName);
    }
}
```

```java
@EntityListeners(AuditingEntityListener.class)
@MappedSuperclass
public abstract class AuditedEntity {

    @CreatedDate   @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @CreatedBy     @Column(name = "created_by", updatable = false)
    private String createdBy;

    @LastModifiedBy @Column(name = "updated_by")
    private String updatedBy;
}
```

Auditing fields only update when the entity passes through Hibernate's lifecycle. Bulk `@Modifying` JPQL updates bypass the listener entirely — set the audit columns explicitly in those statements.

## Soft delete

Prefer an explicit `deleted_at` column filtered in queries over Hibernate's `@SQLRestriction`/`@SQLDelete` annotations. A global restriction applies to every query against the entity, including the ones where you legitimately need the deleted rows (audit, restore, admin views), and there is no clean way to opt out per query. Explicit predicates are more verbose and far easier to reason about. See the `postgres-migrations` skill for the column and partial-index convention.

## Postgres-specific column types

```java
@JdbcTypeCode(SqlTypes.JSON)
@Column(name = "metadata", columnDefinition = "jsonb")
private Map<String, Object> metadata;

@JdbcTypeCode(SqlTypes.ARRAY)
@Column(name = "tags", columnDefinition = "text[]")
private List<String> tags;
```

Use `Instant` for timestamps mapped to `timestamptz`, never `java.util.Date` or `LocalDateTime` — `LocalDateTime` silently drops the offset and makes correctness depend on the JVM's default zone.

## Anti-patterns

| Pattern | Why it breaks |
|---|---|
| `@Data` / `@EqualsAndHashCode` on an entity | Field-based equality triggers lazy loads and recurses on bidirectional associations |
| `EnumType.ORDINAL` (the default) | Reordering constants silently remaps existing rows |
| `ddl-auto: update` | Schema drifts from migrations; destructive changes are never applied consistently |
| `@ManyToOne` left at default `EAGER` | Pays a join on every load, including loads that never touch the association |
| `CascadeType.REMOVE` on `@ManyToOne` | Deleting a child deletes the parent |
| `IDENTITY` on a bulk-insert table | Disables JDBC batching entirely |
| `LocalDateTime` for an instant in time | Drops the offset; correctness depends on the JVM default zone |
