# ActiveRecord BulkUpdate

Updates multiple records with different values in a single database statement.

### TLDR;

| Method  | Description |
| ------------- | ------------- |
| [bulk_update](#bulk_update) | `update`, but then for an Array of instances which are updated in a single query. NOTE: does not trigger callbacks |
| [bulk_update!](#bulk_update!) | `update!`, but then for an Array of instances which are updated in a single query. NOTE: does not trigger callbacks |
| [bulk_update_columns](#bulk_update_columns) | `update_columns`, but then for an Array of instances which are updated in a single query. |
| [bulk_update_all](#bulk_update_all) | `update_all`, but then for multiple update_all statements in a single query. |
| [bulk_insert](#bulk_insert) | `insert_all!`, but then for an Array of instances instead of an Array of attributes. |

### .bulk_update

This method allows you to update a set of records almost exactly as if you would have called `update` on each of those records. The main difference with the regular update method is that the callbacks are not triggered on the instances, except for the 2 callbacks triggered by the validation process. So before_validation and after_validation are triggered, the others are not.

If any of the records is invalid then `false` is returned and the error messages are set on the invalid instances.

Just as the regular update method the `updated_at` is touched, if do not want this you can pass `touch: false`.

### .bulk_update!

This method allows you to update a set of records almost exactly as if you would have called `update!` on each of those records. The main difference with the regular update method is that the callbacks are not triggered on the instances, except for the 2 callbacks triggered by the validation process. So before_validation and after_validation are triggered, the others are not.

If any of the records is invalid then `ActiveRecord::InvalidRecord` is raised and the error messages are set on the invalid instances.

Just as the regular update! method the `updated_at` is touched, if do not want this you can pass `touch: false`.

### .bulk_update_columns

This method allows you to update a set of records exactly as if you would have called `update_columns` on each of those records. The only difference is that all the updates are send to the database in a single statement. Wrapping the updates in a transaction is therefore not necessary.

Old way of updating multiple records of the same model:
 
```ruby
user1 = User.find(1)
user2 = User.find(2)

User.transaction do
  user1.update_columns(name: "foo")
  user2.update_columns(name: "bar")
end
```

The new way of doing it:

```ruby
user1 = User.find(1)
user2 = User.find(2)

user1.name = "foo"
user2.name = "bar"

User.bulk_update_columns([user1, user2])
```

You are not limited to updating a single attribute. Note that in the example below the `name` and `active` attributes are changed. In the subsequent update both these attributes will be updated for all instances in the Array. That means that also the name of user2 and the active state for user1 are updated.

```ruby
user1.name = "foo"
user2.active = true

User.bulk_update_columns([user1, user2])
```

You can combine it with existing scopes:

```ruby
User.where(active: true).limit(2).bulk_update_columns([user1, user2])
```

Just as the regular update_columns method the `updated_at` is not touched, if do want this you can pass `touch: true`.

### .bulk_update_all

If you ever wanted to update multiple database records without having to instantiate the models then `bulk_update_all` will have your back. It basically allows you to define multiple `update_all` statements in one.

Old way of updating multiple rows of the same table:

```ruby
changes = [[1, "foo"], [2, "bar"]]

User.transaction do
  changes.each do |id, name|
    User.where(id: id).update_all(name: name)
  end
end
```

The new way of doing it:

```ruby
changes = [[1, "foo"], [2, "bar"]]
changes = changes.map { |id, name| [{ id: id }, { name: name }] }.to_h

User.bulk_update_all(changes)
```

You are not limited to updating a single column, nor are you limited to using a single column to filter the rows to update. In the syntax below each key is a filter that selects a number of rows and those rows are then updated with the attributes as defined in the value.

```ruby
changes = {
  { country: "GB", locale: "en" } => { currency: "PND", is_eu: false, locale: "en-GB" },
  { country: "NL", locale: "nl" } => { currency: "EUR", is_eu: true, locale: "nl-NL" },
  { country: "US", locale: "en" } => { currency: "USD", is_eu: false, locale: "en-US" }
}

User.bulk_update_all(changes)
```

You can combine it with existing scopes:

```ruby
User.where(active: true).limit(2).bulk_update_all(changes)
```

Just as the regular update_all method the `updated_at` is not touched, if do want this you can pass `touch: true`.

### .bulk_insert

`insert_all!` is a great method to insert multiple records at once, too bad it doesn't accept an Array of ActiveRecord instances. `bulk_insert` is basically a wrapper around `insert_all!` that extracts the attributes for you and after the insert it assigns any default values generated by the database to the given instances.

Old way of inserting multiple rows based on a set of instances:

```ruby
users = [User.new(name: "foor"), User.new(name: "bar")]

user_ids = User.insert_all!(users.map(&:attributes), returning: [:id])
users.zip(user_ids).each do |user, user_id|
  user.id = user_id
end
```

The new way of doing it:

```ruby
users = [User.new(name: "foor"), User.new(name: "bar")]

User.bulk_insert(users)
```

You can combine it with existing scopes:

```ruby
User.where(active: true).bulk_insert(users)
```

### How do the update statements work

Constructs a single, efficient query to update multiple rows of a single table at once. Below you can find the SQL statement that is generated by the first examples in this readme.

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

The code in this gem mirrors very closely the code used by methods like `update_all` and `insert_all`. It uses existing ActiveRecord classes and methods where-ever that is possible. This has the benefit that is behaves just as other ActiveRecord methods that you are used to, including raising the same type of exceptions and having the same logging.

### Limitations

- Only works for PostgreSQL
- Only works when all records belong to the same model, does not work with STI.

### TODO
- Add CI build for tests and linting!
- Auto-deploy to rubygems!
- Add bulk_create and bulk_create!?
- Add bulk_save and bulk_save!?
- Add the option to execute callbacks? Complex to implement and `around` callbacks are basically impossible.
- Add the option to set the created_at column during bulk_insert?
- Add the ability to update in_batches?
- Add optimistic locking?
- Improve performance when including a limit, order or offset clause
