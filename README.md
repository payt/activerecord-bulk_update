# ActiveRecord BulkUpdate

Creates, updates or deletes multiple records in a single database statement.

### .bulk_create

Inserts multiple records into the database in a single query, and returns the (unpersisted) records.

```ruby
users = [User.new(name: "foo"), User.new(name: "bar")]

User.where(active: true).bulk_create(users)
```

| Option           | Default | Description                                                                    |
| ---------------- | ------- | ------------------------------------------------------------------------------ |
| validate         | true    | when true it validates the records.                                            |
| ignore_persisted | false   | when true it ignores any persisted records, when false it raises an exception. |

### .bulk_create!

see: [bulk_create](#bulk_create)

Except it raises an `ActiveRecord::BulkInvalid` exception when any of the records are invalid.

### .bulk_delete

Deletes multiple records in a single delete query.

```ruby
users = User.where(id: [1, 2])

User.where(email: nil).bulk_delete(users)
```

### .bulk_delete_all

Combines multiple delete_all filters into a single delete query.

```ruby
filters = [{ email: nil }, { name: "y", country: [nil, "NL"] }]

User.where(active: false).bulk_delete_all(filters)
```

### .bulk_insert

Inserts multiple records into the database in a single query.

```ruby
users = [User.new(name: "foo"), User.new(name: "bar")]

User.where(active: true).bulk_insert(users)
```

| Option            | Default | Description                                                                    |
| ----------------- | ------- | ------------------------------------------------------------------------------ |
| ignore_persisted  | false   | when true it ignores any persisted records, when false it raises an exception. |
| ignore_duplicates | true    | when true it ignores any duplicate records, when false it raises an exception. |
| unique_by         | nil     | when set, record uniqueness is verified only according to this constraint. See [the insert_all documentation for a full description of this parameter](https://api.rubyonrails.org/v7.1.3.4/classes/ActiveRecord/Persistence/ClassMethods.html#method-i-insert_all). Requires `ignore_duplicates` to be false |

### .bulk_insert!

Inserts multiple records into the database in a single query and raises an exception in case of duplicate records.

```ruby
users = [User.new(name: "foo"), User.new(name: "bar")]

User.where(active: true).bulk_insert!(users)
```

| Option            | Default | Description                                                                    |
| ----------------- | ------- | ------------------------------------------------------------------------------ |
| ignore_persisted  | false   | when true it ignores any persisted records, when false it raises an exception. |
| ignore_duplicates | false   | when true it ignores any duplicate records, when false it raises an exception. |
| unique_by         | nil     | when set, record uniqueness is verified according to this constraint. See [the insert_all documentation for a full description of this parameter](https://api.rubyonrails.org/v7.1.3.4/classes/ActiveRecord/Persistence/ClassMethods.html#method-i-insert_all). Requires `ignore_duplicates` to be false |

#### extras

- it assigns all default values generated by the database to the given instances, so no need to reload the instances.

### .bulk_upsert

Upserts multiple records into the database in a single query, when no unique key is given it will render an error `ActiveRecord::RecordNotUnique` if there are any duplicate rows.

```ruby
users = [User.new(name: "foo"), User.new(name: "bar")]

User.where(active: true).bulk_upsert(users, unique_by: :name)
```

| Option           | Default | Description                                                                    |
| ---------------- | ------- | ------------------------------------------------------------------------------ |
| ignore_persisted | false   | when true it ignores any persisted records, when false it raises an exception. |
| unique_key       | nil     | when not given it will render an error if there are duplicates                 |

Unique indexes can be identified by columns or name:

```ruby
unique_by: :name
unique_by: %i[ company_id name ]
unique_by: :index_name_on_company
```

#### extras

- it assigns all default values generated by the database to the given instances, so no need to reload the instances.

### .bulk_update

```ruby
user1 = User.find(1)
user2 = User.find(2)

user1.name = "foo"
user2.email = "bar@example.com"

User.where(active: true).bulk_update([user1, user2], validate: false)
```

| Option   | Default | Description                                 |
| -------- | ------- | ------------------------------------------- |
| validate | true    | when true it validates the records.         |
| touch    | true    | when true it sets the updated_at timestamp. |

### .bulk_update!

see: [bulk_update](#bulk_update)

Except it raises an `ActiveRecord::BulkInvalid` exception when any of the records are invalid.

### .bulk_update_columns

see: [bulk_update](#bulk_update)

Except the default values for the options are different.

| Option   | Default | Description                                 |
| -------- | ------- | ------------------------------------------- |
| validate | false   | when true it validates the records.         |
| touch    | false   | when true it sets the updated_at timestamp. |

### .bulk_update_all

```ruby
changes = {
  { country: "GB", locale: "en" } => { currency: "PND", is_eu: false, locale: "en-GB" },
  { country: "NL", locale: "nl" } => { currency: "EUR", is_eu: true, locale: "nl-NL" },
  { country: "US", locale: "en" } => { currency: "USD", is_eu: false, locale: "en-US" }
}

User.where(active: true).bulk_update_all(changes)
```

| Option | Default | Description                                 |
| ------ | ------- | ------------------------------------------- |
| touch  | false   | when true it sets the updated_at timestamp. |

### .bulk_valid?

Returns `true` if all records are valid.

### .bulk_invalid?

Returns `true` if any of the records is invalid.

### .bulk_errors

Returns an Array of Hashes containing the error details of the invalid records, if any. It does not trigger validations, so the Array will always be empty if no validations have been triggered yet.

It does not return details for valid records. In order to figure out to which record the errors belong the `id` of the record included as well as its index in the given collection.

#### Callbacks

The main difference with the regular ActiveRecord methods is that most callbacks are not triggered on the instances. Only the following callbacks are triggered:

- `before_validation`
- `after_validation`
- `before_commit`
- `after_commit`
- `after_rollback`

### How do the bulk update statements work

Constructs a single, efficient query to update multiple rows of a single table at once. Below you can find the SQL statement that is generated by the [bulk_update](#bulk_update) example in this readme.

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

The code in this gem mirrors very closely the code used by methods like `update_all` and `insert_all`. It uses existing ActiveRecord classes and methods where-ever that is possible. This has the benefit that is behaves just as other ActiveRecord methods that you are used to, including raising the same type of exceptions and using the same logging.

### Limitations

- Only works for PostgreSQL
- Only works when all records belong to the same model, does not work with STI.
- Does not support optimistic locking.
- Does not support in_batches.

### TODO

- Add CI build for tests and linting!
- Auto-deploy to rubygems!
- Add bulk_destroy
- Add bulk_save
- Add the option to execute callbacks? Complex to implement and `around` callbacks are basically impossible.
- Always wrap the bulk actions in a transaction?
  - The transaction callbacks are currently only triggered if the bulk action is called from within a wrapping transaction
  - The validation callbacks are not performed within a transaction
- Improve performance when including a limit, order or offset clause in an update statement

### Development

- Easiest way to start development is using VSCode with the Devcontainer extension. This will automatically install all dependencies in Docker containers and open VSCode in the context of the gem.
- Another option is to use Docker compose to setup the dependencies (`docker compose build`), then edit the code locally on your machine and run tests using `docker compose up`
- If you do not want to use Docker install Ruby and Postgresql locally. Install Ruby dependencies with `bundle install`. Set PG env variables to connect to a database to run the test on. Check test/support/database_setup.rb for details.

### Testing

- Run the tests: `bundle exec rake test`
