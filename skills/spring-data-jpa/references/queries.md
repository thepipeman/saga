# Queries and projections

Spring Data JPA 4.0 (Spring Data 2025.1, Spring Boot 4.x).

## Choosing a query mechanism

Work down this list and stop at the first one that fits:

1. **Derived query method** — for one to three predicates. Self-documenting, validated at build time under AOT.
2. **`@Query` with JPQL** — once the method name would stop being readable, or the query needs a join, an aggregate, or a constructor expression.
3. **`Specification`** — when the predicate set is genuinely dynamic (an optional-filter search endpoint).
4. **`@NativeQuery`** — only for Postgres constructs JPQL cannot express: `jsonb` operators, window functions, `ON CONFLICT`, full-text search, recursive CTEs.

A derived method name carrying five conditions is worse than the `@Query` it replaces. `findByStatusAndCustomerIdAndCreatedAtBetweenAndTotalGreaterThanOrderByCreatedAtDesc` is a code smell, not a convention.

## Derived queries

```java
Optional<Order> findByCustomerReference(String customerReference);

List<Order> findByStatus(OrderStatus status, Limit limit);

Page<Order> findByCustomerId(UUID customerId, Pageable pageable);

boolean existsByCustomerReference(String customerReference);

long countByStatus(OrderStatus status);
```

`Limit`, `Pageable`, and `Sort` are special parameters. `Pageable` already carries both a sort and a limit, so it cannot be combined with either — `Pageable` + `Sort` and `Pageable` + `Limit` are both invalid. Each special parameter may appear at most once, and all three expect non-null values; pass `Sort.unsorted()`, `Pageable.unpaged()`, or `Limit.unlimited()` rather than `null`.

## @Query

Always use named parameters with `@Param`. Positional `?1` binding breaks silently when someone reorders the method signature:

```java
@Query("""
    select o from Order o
    where o.status = :status
      and o.createdAt >= :since
    """)
List<Order> findRecentByStatus(@Param("status") OrderStatus status,
                               @Param("since") Instant since,
                               Limit limit);
```

Text blocks for anything past one line — the query is the thing being reviewed, so keep it readable.

`Sort` works with `@Query`, and the sort properties are validated against the domain model or the query's aliases. To sort by an expression that isn't a plain path (a function call), use `JpaSort.unsafe("...")` — the name is accurate, it skips validation, so never build it from user input.

## @NativeQuery

`@NativeQuery` is the composed form of `@Query(nativeQuery = true)` and additionally exposes `sqlResultSetMapping`:

```java
@NativeQuery(value = """
    select * from sales.orders
    where metadata @> cast(:filter as jsonb)
    """)
List<Order> findByMetadataContaining(@Param("filter") String filter);
```

A paginated native query needs an explicit `countQuery` — Spring Data cannot derive one from arbitrary SQL:

```java
@NativeQuery(
    value = "select * from sales.orders where customer_id = :customerId",
    countQuery = "select count(*) from sales.orders where customer_id = :customerId")
Page<Order> findByCustomer(@Param("customerId") UUID customerId, Pageable pageable);
```

Native queries bypass JPQL's schema awareness, so they break silently when a migration renames a column. Keep them few, and cover each one with an integration test against a real Postgres (see the `testcontainers-testing` skill).

## Projections

**Prefer projecting to a DTO over loading an entity you're only going to read.** A projection fetches exactly the columns named, skips the persistence context, and skips dirty-check snapshots.

Constructor expression into a record — explicit and refactor-safe:

```java
public record OrderSummary(UUID id, String customerReference, OrderStatus status, BigDecimal total) { }

@Query("""
    select new com.example.order.OrderSummary(o.id, o.customerReference, o.status, o.total)
    from Order o where o.customerId = :customerId
    """)
List<OrderSummary> findSummariesByCustomer(@Param("customerId") UUID customerId);
```

Interface-based closed projection — no query needed, Spring Data derives the column list from the getters:

```java
public interface OrderRef {
    UUID getId();
    String getCustomerReference();
}

List<OrderRef> findByStatus(OrderStatus status);
```

Open projections (`@Value("#{target.x + target.y}")`) load the full entity to evaluate the SpEL expression, which defeats the point — do the computation in the DTO or the service instead.

Dynamic projections let one query method serve several shapes:

```java
<T> List<T> findByStatus(OrderStatus status, Class<T> type);
```

Note that dynamic projections are excluded from AOT repository generation and fall back to reflection.

## Pagination and scrolling

| Return type | Cost | Use when |
|---|---|---|
| `Page<T>` | Runs a second `count` query | The UI needs a total count or page numbers |
| `Slice<T>` | No count query | Infinite scroll / "load more" — only needs to know if another page exists |
| `Window<T>` | No count, no `OFFSET` | Deep pagination over a large or actively-written table |

`Page` is the default reach and often the wrong one — the count query against a large table can cost more than the page itself. If the caller doesn't render a total, return `Slice`.

**Keyset scrolling** avoids `OFFSET`, whose cost grows linearly with depth and whose results shift when rows are inserted mid-scroll:

```java
Window<Order> findByStatus(OrderStatus status, ScrollPosition position, Sort sort);
```

```java
var window = repository.findByStatus(PENDING, ScrollPosition.keyset(), Sort.by("createdAt", "id"));
while (window.hasNext()) {
    window = repository.findByStatus(PENDING, window.positionAt(window.size() - 1), sort);
}
```

The sort must end in a unique column (typically the id) or the keyset has no stable tiebreaker. Keyset scrolling does not work with string-based `@Query` or stored procedures, and methods taking a `ScrollPosition` are excluded from AOT processing.

## Specifications

The JPA equivalent of building a condition up from `DSL.noCondition()` in jOOQ. Extend `JpaSpecificationExecutor` and compose:

```java
public interface OrderRepository extends ListCrudRepository<Order, UUID>,
                                         JpaSpecificationExecutor<Order> { }
```

```java
final class OrderSpecs {

    static Specification<Order> hasStatus(OrderStatus status) {
        return (root, query, cb) -> cb.equal(root.get(Order_.status), status);
    }

    static Specification<Order> createdAfter(Instant since) {
        return (root, query, cb) -> cb.greaterThan(root.get(Order_.createdAt), since);
    }
}
```

```java
Specification<Order> spec = Specification.unrestricted();
if (criteria.status() != null)  spec = spec.and(OrderSpecs.hasStatus(criteria.status()));
if (criteria.since() != null)   spec = spec.and(OrderSpecs.createdAfter(criteria.since()));

Page<Order> page = repository.findAll(spec, pageable);
```

Use the generated static metamodel (`Order_.status`) rather than string attribute names so a renamed field is a compile error. That requires the `hibernate-processor` annotation processor on the build path.

Keep specification factories in a dedicated final class with a private constructor — not scattered across services.

## Modifying queries

Bulk updates and deletes are the right tool when you'd otherwise load thousands of entities to change one column. They bypass the persistence context, which is exactly the trade-off:

```java
@Modifying(clearAutomatically = true, flushAutomatically = true)
@Query("update Order o set o.status = :status where o.id in :ids")
int markStatus(@Param("ids") Collection<UUID> ids, @Param("status") OrderStatus status);
```

- `flushAutomatically = true` writes pending changes before the bulk statement, so it doesn't operate on stale rows.
- `clearAutomatically = true` clears the persistence context afterwards, so subsequently-read entities reflect the update rather than a stale cached copy.
- Auditing listeners and `@Version` do **not** fire for bulk statements. Set `updated_at` and bump the version in the statement itself if the entity is audited or versioned.
- The method must run inside a transaction and returns the affected row count.

For single-entity updates, don't write a modifying query at all — load the entity in a `@Transactional` method and mutate it. Dirty checking issues the update at flush, and auditing and versioning both work.

## Things not to do

- **Don't call `save()` on an entity that's already managed.** Inside a transaction, mutating a loaded entity is enough — dirty checking handles the update. The redundant `save()` reads as though something extra is happening.
- **Don't use `getOne`/`getById`.** Use `getReferenceById` when you only need a proxy to set a foreign key without loading the row, and `findById` when you actually need the state.
- **Don't return `Stream<T>` from a repository into a service** unless the caller closes it in a try-with-resources inside the transaction. A leaked cursor holds the connection.
- **Don't expose `Sort` built from raw request parameters.** Whitelist sortable fields; `JpaSort.unsafe` on user input is an injection vector.
- **Don't put `@Transactional` on the repository interface.** Transaction boundaries belong to the service layer, where the unit of work is actually defined.
