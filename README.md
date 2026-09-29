# Translateable

[![CI Ruby](https://github.com/olegantonyan/translateable/actions/workflows/tests.yml/badge.svg)](https://github.com/olegantonyan/translateable/actions/workflows/tests.yml)
[![Gem Version](https://badge.fury.io/rb/translateable.svg)](https://badge.fury.io/rb/translateable)

Allows you to store text data in multiple languages with your ActiveRecord models. Similar to [globalize](https://github.com/globalize/globalize), but with a few differences:

1. Uses a single field in the table. No additional tables are required to store translated data. PostgreSQL 9.4+ is required for this (JSONB).
2. Provides easy integration with forms using nested attributes, so you can create records with multiple translations in one form. Together with [nested_form_fields](https://github.com/ncri/nested_form_fields) you can dynamically add/delete/update translations without a single line of JavaScript.

```ruby
I18n.locale = :en
post = Post.create(title: 'hello')
post.title #=> hello

I18n.locale = :ru
post.update(title: 'привет')
post.title #=> привет

I18n.locale = :en
post.title #=> hello
```

It adds a very thin abstraction layer on top of a JSONB field. All data is stored in a simple JSON structure: `{ "locale_name": "data" }`. JSONB can be indexed (this is the main reason to use it instead of plain JSON, which is available in earlier Postgres versions).

## Requirements

- PostgreSQL >= 9.4
- ActiveRecord >= 5.0 (tested with 7.0–8.1)
- I18n

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'translateable'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install translateable

## Usage

Include `Translateable` into your model (or into `ApplicationRecord` to make it available in all models).

Call the `translateable` macro with a list of attributes you want to be translateable:
```ruby
class Post < ActiveRecord::Base
  include Translateable

  translateable :title
end
```

Now the `title` attribute is translateable:
```ruby
I18n.locale = :en
post = Post.create(title: 'hello')
post.title #=> hello

I18n.locale = :ru
post.update(title: 'привет')
post.title #=> привет

I18n.locale = :en
post.title #=> hello

I18n.locale = :it # oops! no translation for 'it' locale, use translation for `I18n.default_locale`
post.title #=> hello
```

You can pass multiple attributes:
```ruby
translateable :title, :body
```

If there is no translation for the selected locale, then `I18n.default_locale` will be used. If there is no translation for `I18n.default_locale`, then the first available one will be used. You can override this behavior with the `strict` option; in this case you'll get `nil` if there is no translation for the selected locale:
```ruby
I18n.locale = :en
post = Post.create(title: 'hello')
post.title #=> hello

I18n.locale = :ru
post.title #=> hello
post.title(strict: true) #=> nil
```

You can assign data for all locales at once as a hash:
```ruby
post = Post.create(title: { en: 'hello', ru: 'привет' })
I18n.with_locale(:en) do
  post.title #=> 'hello'
end
I18n.with_locale(:ru) do
  post.title #=> 'привет'
end
```

You can easily create translated data with a form using nested attributes.

For example, with [simple_form](https://github.com/heartcombo/simple_form) and [nested_form_fields](https://github.com/ncri/nested_form_fields):
```haml
= simple_form_for @post do |f|
  = f.label(:title)
  = f.nested_fields_for Translateable.translateable_attribute_by_name(:title), class_name: 'Translateable::AttributeValue' do |ff|
    = ff.input :data, label: false
    = ff.input :locale, collection: I18n.available_locales, include_blank: false, label: false
    = ff.remove_nested_fields_link 'Remove translation', role: 'button'
  = f.add_nested_fields_link Translateable.translateable_attribute_by_name(:title), 'Add translation', role: 'button'
  = f.button :submit
```

Or with the built-in `form_for` and [nested_form_fields](https://github.com/ncri/nested_form_fields):
```haml
= form_for @post do |f|
  = f.label :title
  = f.nested_fields_for Translateable.translateable_attribute_by_name(:title), class_name: 'Translateable::AttributeValue' do |ff|
    = ff.text_field :data
    = ff.select :locale, I18n.available_locales
    = ff.remove_nested_fields_link 'Remove translation', role: 'button'
  = f.add_nested_fields_link Translateable.translateable_attribute_by_name(:title), 'Add translation', role: 'button'

  = f.submit
```
Don't forget about strong parameters in your controller:
```ruby
def post_params
  attrs = [:title] + Post.translateable_permitted_attributes
  params.require(:post).permit(*attrs)
end

# `translateable_permitted_attributes` method provides strong_params for all translateable attributes
# for example, with the `title` attribute those will be: `title_translateable_attributes: [:locale, :data, :_destroy]`
```
Now you can add/delete/update the `title` attribute value in different languages via a single form.

A plain field works too and edits the current locale's text, also when the form is re-rendered after a failed validation:
```haml
= form_for @post do |f|
  = f.text_field :title
```

### Migration

Attributes must exist with the `JSONB` type in the database, so create a migration:
```ruby
class AddTitleToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :title, :jsonb, null: false, default: {}
  end
end
```

If you already have data and want to migrate it to the new translateable structure, use the provided generator:
```
bin/rails generate translateable:migration posts title
```
This will create a reversible migration for data in the `title` field of the `posts` table. By default, the existing data will be moved into `I18n.default_locale`. If you want to use another locale, provide it as a third argument:
```
bin/rails generate translateable:migration posts title ru
```
Now all existing data will be transferred into the new structure with the 'ru' locale.

Example (using the 'en' locale):
```sql
-- before migration
SELECT id, title FROM posts;
 id | title
----+-------
  1 | hello
  2 | world

-- after migration
SELECT id, title FROM posts;
 id |      title
----+-----------------
  1 | {"en": "hello"}
  2 | {"en": "world"}
```

If the field was indexed, the migration re-creates the index as a GIN index. If you need a different index (e.g. on a JSON path), change the migration manually.

### Queries

You'll probably want to create scopes for these kinds of queries.

```ruby
# get posts where `title` with `en` locale is 'hello'
Post.where("title->>'en' = ?", 'hello')

# get posts where `title` is 'hola' with any locale
Post.where("EXISTS (SELECT 1 FROM jsonb_each_text(posts.title) j WHERE j.value = ?)", 'hola')

# get posts where `title` LIKE 'прив' with any locale ignoring case
Post.where("EXISTS (SELECT 1 FROM jsonb_each_text(posts.title) j WHERE lower(j.value) LIKE ?)", '%прив%')
```

I use this concern:
```ruby
# app/models/concerns/jsonb_queryable.rb
module JsonbQueryable
  extend ActiveSupport::Concern

  included do
    # http://stackoverflow.com/questions/36250331/query-postgres-jsonb-by-value-regardless-of-keys/36251296#36251296
    scope :where_jsonb_value, ->(attribute, value) {
      column = connection.quote_table_name("#{table_name}.#{attribute}")
      where("EXISTS (SELECT 1 FROM jsonb_each_text(#{column}) j WHERE j.value = ?)", value)
    }

    scope :where_jsonb_value_like, ->(attribute, value, case_sens = false) {
      column = connection.quote_table_name("#{table_name}.#{attribute}")
      pattern = "%#{sanitize_sql_like(value)}%"
      if case_sens
        where("EXISTS (SELECT 1 FROM jsonb_each_text(#{column}) j WHERE j.value LIKE ?)", pattern)
      else
        where("EXISTS (SELECT 1 FROM jsonb_each_text(#{column}) j WHERE lower(j.value) LIKE lower(?))", pattern)
      end
    }
  end
end
```

Refer to the [Postgres documentation](https://www.postgresql.org/docs/current/functions-json.html).

### Troubleshooting

When a model is loaded, `translateable` checks that each attribute has a matching column. The check is skipped if there is no active database connection or the table doesn't exist yet. If it still causes problems (e.g. a database that doesn't exist upon loading), you can disable it by setting the `DISABLE_TRANSLATEABLE_SANITY_CHECK` environment variable (any value) or by passing `sanity_checks: false`, for example `translateable :title, sanity_checks: false`.

## TODO

- Add options (fallback locales lookup behavior maybe?)
- More clever database management for testing (temp schema or similar)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Tests need a running PostgreSQL server, configured via `POSTGRES_HOST`, `POSTGRES_PORT` and `POSTGRES_PASSWORD`. To test against a specific Rails version, use one of the gemfiles, e.g. `BUNDLE_GEMFILE=gemfiles/8.1.gemfile bundle exec rspec`.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/olegantonyan/translateable. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
