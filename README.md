# ActiveRecord BulkUpdate

Updates multiple records with different values in a single database statement.
It fills the space left between `update_all` and `update_columns`.

### How does it work

Constructs a single, efficient query to update multiple records at once. It does not trigger callbacks nor validations.

#### set of ActiveRecord instances

You can manipulate a set of ActiveRecord objects and have the `bulk_update` update them all in one go.

```ruby
user1 = User.find(1)
user2 = User.find(2)

user1.name = "foo"
user2.name = "bar"

User.bulk_update([user1, user2])
```

The resulting statement updates both records at once.

```sql
UPDATE "users"
SET "name" = "source"."_name"
FROM (
  VALUES (
    CAST(1 AS integer), CAST('foo' AS character varying),
    (2, 'bar')
  )
) AS source(id, _name)
WHERE "source"."id" = "users"."id"
```

#### Hash of hashes

If you want more control over what to update you can pass a Hash.
The keys within this Hash are themselves Hashes that are used to identify which records to update, the values are also Hashes and represent the changes that will be made.

The example below results in the exact same SQL as in the example above.

```ruby
User.bulk_update(
  { id: 1 } => { name: "foo" },
  { id: 2 } => { name: "bar" }
)
```

The example below shows that you chain `bulk_update` just as with `update_all`, you can also use multiple columns to identify which records to update and updates more than 1 column at once. Just as with `update_all`, this statement will update all records that match the constraints and returns the number of affected rows.

```ruby
User.where(active: true).bulk_update(
  { country: "GB", locale: "en" } => { currency: "PND", is_eu: false },
  { country: "NL", locale: "nl" } => { currency: "EUR", is_eu: true },
  { country: "??", locale: nil } => { currency: nil, is_eu: nil }
)
```

```sql
UPDATE "users" SET
  "currency" = "source"."_currency",
  "is_eu" = "source"."_is_eu"
FROM (
  VALUES (
    CAST("GB" AS character varying), CAST("en" AS character varying), CAST("PND" AS character varying), CAST(FALSE AS boolean),
    ('NL', 'nl', 'EUR', TRUE),
    ('??', NULL, NULL, NULL)
  )
) AS source(country, locale, _currency, _is_eu)
WHERE "source"."country" = "users"."country"
AND   "source"."locale" = "users"."locale"
AND   "users"."active" = TRUE
```

### Limitations

- Only works for PostgreSQL
- Only works when all records belong to the same model

### TODO
- Add tests!
- Add the option to validate records prior to updating?
- Add the option to execute callbacks?
- Add the option to update the updated_at column?
- Add the option to define returning columns?
- Add the ability to update in_batches?
- Add optimistic locking?
- Improve performance when including a limit, order or offset clause
