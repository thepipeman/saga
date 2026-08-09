# JPA performance

The failure mode of a JPA codebase is almost never one slow query — it is a correct-looking method that issues hundreds of queries nobody counted. Everything here is about making the query count visible and deliberate.

## N+1: what it looks like

```java
@Transactional(readOnly = true)
public List<OrderSummary> listOrders() {
    return orderRepository.findAll().stream()          // 1 query
        .map(o -> new OrderSummary(o.getId(), o.getItems().size()))   // N queries
        .toList();
}
```

Nothing in that code says "issue 101 queries," which is why it survives review. The lazy collection access inside the loop is the whole problem.

The same bug appears without a loop when `spring.jpa.open-in-view` is left on — the lazy load happens during JSON serialization, outside any code you wrote. This is the main reason the skill mandates `open-in-view: false`: it converts a silent N+1 into a `LazyInitializationException` at the exact line that caused it.

## Fixing it

**`@EntityGraph`** — declarative, keeps the derived query, best default:

```java
@EntityGraph(attributePaths = {"items", "customer"})
Optional<Order> findWithItemsById(UUID id);

@EntityGraph(attributePaths = "items")
List<Order> findByStatus(OrderStatus status);
```

**`JOIN FETCH`** — when you also need a `where` clause over the joined side, or a fetch two levels deep:

```java
@Query("""
    select distinct o from Order o
    join fetch o.items i
    join fetch o.customer c
    where o.status = :status
    """)
List<Order> findByStatusWithItems(@Param("status") OrderStatus status);
```

**Batch fetching** — when the association is traversed sometimes and joining always would be wasteful. Hibernate loads the pending proxies in `IN (...)` batches, turning N queries into N/size:

```yaml
spring.jpa.properties.hibernate.default_batch_fetch_size: 25
```

This is a good global default even in a codebase that uses entity graphs properly — it caps the damage of an N+1 nobody caught.

**Projection** — the best fix when you never needed the entity graph at all. If the caller wants a summary, query a summary (see `references/queries.md`).

## Two traps that specifically bite JOIN FETCH

**Pagination over a fetched collection.** `Pageable` + `join fetch` on a to-many association cannot be expressed in SQL — `LIMIT` would cut the joined rows, not the entities. Hibernate's historical behaviour was to fetch the entire result set and paginate in memory, warning `HHH000104` into a log nobody reads. Set:

```yaml
spring.jpa.properties.hibernate.query.fail_on_pagination_over_collection_fetch: true
```

so it throws instead. The fix is two queries: page the ids, then fetch the collections for that id set.

```java
Page<UUID> ids = repository.findIdsByStatus(status, pageable);
List<Order> orders = repository.findAllWithItemsByIdIn(ids.getContent());
```

**`MultipleBagFetchException`.** Fetching two `List` associations in one query is a cartesian product Hibernate refuses to produce. Options, in order of preference: fetch one and let `default_batch_fetch_size` handle the other; change one to a `Set`; or split into two queries against the same persistence context, which merges them for free.

## Detecting query counts

Guessing is not a strategy — assert it. Hibernate's statistics give you a count you can put in a test:

```java
@Test
void listingOrdersIssuesOneQuery() {
    var stats = entityManager.getEntityManagerFactory()
        .unwrap(SessionFactory.class).getStatistics();
    stats.clear();

    service.listOrders();

    assertThat(stats.getPrepareStatementCount()).isEqualTo(1);
}
```

Enable it with `spring.jpa.properties.hibernate.generate_statistics: true` in the test profile only — it has a runtime cost.

For local diagnosis, log the SQL with bound parameters:

```yaml
logging.level:
  org.hibernate.SQL: DEBUG
  org.hibernate.orm.jdbc.bind: TRACE
```

(`org.hibernate.orm.jdbc.bind` is the Hibernate 6+ category; the old `org.hibernate.type.descriptor.sql` logger no longer exists.) Never enable either in production — every statement and every bound value, including personal data, lands in the log.

## Read-only transactions

```java
@Transactional(readOnly = true)
public OrderView findOrder(UUID id) { ... }
```

`readOnly = true` tells Hibernate to skip the dirty-check snapshot for every loaded entity and to skip the flush before commit. On a query returning a few hundred entities that is a measurable difference, and it also means an accidental mutation in a read path fails loudly instead of persisting.

## Batch writes

Batching requires three things together — any one missing and it silently does nothing:

```yaml
spring:
  jpa:
    properties:
      hibernate:
        jdbc.batch_size: 50
        order_inserts: true
        order_updates: true
  datasource:
    url: jdbc:postgresql://host/db?reWriteBatchedInserts=true
```

1. `batch_size` set.
2. The entity must **not** use `GenerationType.IDENTITY` — it forces an immediate insert per row to retrieve the key, which defeats batching entirely. Use `SEQUENCE` with a matching `allocationSize`.
3. `reWriteBatchedInserts=true` on the pgjdbc URL, which rewrites the batch into a single multi-row `INSERT`.

For genuinely large loads, flush and clear periodically so the persistence context doesn't grow without bound:

```java
@Transactional
public void importAll(List<Order> orders) {
    for (int i = 0; i < orders.size(); i++) {
        entityManager.persist(orders.get(i));
        if (i % 50 == 0) {
            entityManager.flush();
            entityManager.clear();
        }
    }
}
```

Past a certain volume, JPA is the wrong tool — a `COPY` or a plain JDBC batch will beat it by an order of magnitude and won't hold a persistence context at all.

## Avoiding unnecessary loads

Setting a foreign key does not require loading the target row:

```java
order.setCustomer(customerRepository.getReferenceById(customerId));   // no SELECT
```

`getReferenceById` returns a proxy; Hibernate writes the id into the FK column at flush. It throws `EntityNotFoundException` only if something later touches a field on the proxy — so validate the id's existence separately when that matters.

## Connection and transaction hygiene

- A `@Transactional` method holds a pooled connection for its entire duration. Anything slow and non-database inside that scope — an HTTP call, a file write, a `Thread.sleep` — is holding a connection hostage under load. Do the DB work, commit, then do the rest.
- Keep transactions narrow. A single service method wrapping five unrelated repository calls will hold locks across all of them.
- Long read-only reports belong outside the request transaction entirely, or on a read replica.

## Second-level cache

Off by default. Leave it off unless there is a measured, named problem it solves and a clear answer for how entries are invalidated across instances. A stale second-level cache in a multi-instance deployment is a much worse problem than the query it saved.

## Checklist for any new query path

- [ ] Query count is known and bounded — no lazy access inside a loop or a stream
- [ ] Collection-returning methods take a `Pageable`, `Limit`, or a selective predicate
- [ ] Associations needed by the caller are fetched by the query, not by OSIV
- [ ] `Page` only where a total count is actually rendered; otherwise `Slice` or `Window`
- [ ] Read paths are `@Transactional(readOnly = true)`
- [ ] The predicate's columns are indexed — see the `postgres-migrations` skill
- [ ] No `JOIN FETCH` of a to-many combined with `Pageable`
