# Translateable

[![CI Ruby](https://github.com/olegantonyan/translateable/actions/workflows/tests.yml/badge.svg)](https://github.com/olegantonyan/translateable/actions/workflows/tests.yml)
[![Gem Version](https://badge.fury.io/rb/translateable.svg)](https://badge.fury.io/rb/translateable)

Allows you to store text data in multiple languages with your ActiveRecord models. Similar to [globalize](https://github.com/globalize/globalize), but with a few differences:

1. Works with Rails 5
2. Uses single field in the table. No additional tables required to store translated data. PostgreSQL 9.4 is required to do this (JSONB)
3. Provides easy integration with forms using nested attributes so you can create records with multiple translations in one form. Together with [nested_form_fields](https://github.com/ncri/nested_form_fields) you can dynamically add/delete/update translations without a single line of JavaScript.

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

It adds very thin abstraction layer on top of JSONB field. All data is stored in a simple JSON structure: `{ "locale_name": "data" }`. JSONB can be indexed (this is the main reason to ​use​ it instead of just JSON, ​available​ in earlier Postgres versions).

## Requirements

- PostgreSQL >= 9.4
- ActiveRecord >= 4.2
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

Include `Translateable` into your model (or `ApplicationRecord` if you are on Rails 5 and want to include it into all models).

Call `translateable` macro with a list of attributes you want to be translateable:
```ruby
class Post < ActiveRecord::Base
  include Translateable

  translateable :title
end
```

Now `title` attribute is translateable:
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

If there is no translation for a selected locale, than `I18n.default_locale` will be used. If there is no translation for `I18n.default_locale`, than the first available ​one will be used. You can override this behavior with `strict` option, in this case you'll get `nil` if there is no translation for the selected locale:
```ruby
I18n.locale = :en
post = Post.create(title: 'hello')
post.title #=> hello

I18n.locale = :ru
post.title #=> hello
post.title(strict: true) #=> nil
```

You can assign all locales data as a hash at once:
```ruby
post = Post.create(title: { en: 'hello', ru: 'привет' })
I18n.with_locale(:en) do
  post.title #=> 'hello'
end
I18n.with_locale(:ru) do
  post.title #=> 'привет'
end
```

You can easily create translated data with form using nested attributes

For example, with [simple_form](https://github.com/plataformatec/simple_form) and [nested_form_fields](https://github.com/ncri/nested_form_fields):
```haml
= simple_form_for @post do |f|
  = f.label(:title)
  = f.nested_fields_for Translateable.translateable_attribute_by_name(:title), class_name: 'OpenStruct' do |ff|
    = ff.input :data, label: false
    = ff.input :locale, collection: I18n.available_locales, include_blank: false, label: false
    = ff.remove_nested_fields_link 'Remove translation', role: 'button'
  = f.add_nested_fields_link Translateable.translateable_attribute_by_name(:title), 'Add translation', role: 'button'
  = f.button :submit
```

Or with built-in `form_for` and [nested_form_fields](https://github.com/ncri/nested_form_fields):
```haml
= form_for @post do |f|
  = f.label :title
  = f.nested_fields_for Translateable.translateable_attribute_by_name(:title), class_name: 'OpenStruct' do |ff|
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
# for example with `title` attribute those will be: `title_translateable_attributes: [:locale, :data, :_destroy]`
```
Now you can add/delete/update `title` attribute value in different languages via a single form.

### Migration

Attributes must exist with `JSONB` type in a database, so create a migration:
```ruby
class AddTitleToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :title, :jsonb, null: false, default: {}
  end
end
```

If you already have data​ and you want to migrate it to a new translateable structure, use ​a generator provided:
```
bin/rails generate translateable:migration posts title
```
This will create a reversible migration for data in `title` field of the `posts` table. By default, the existent data will be moved into `I18n.default_locale`. If you want to use another locale, provide it as a third argument:
```
bin/rails generate translateable:migration posts title ru
```
Now all existent data will be transfered into new structure with 'ru' locale.

Example (using 'en' locale):
```sql
# before migration
SELECT id,title FROM posts;
 id |     title                     
----+-----------------
 1  | "hello"
 2  | "world"

 # after migration
 SELECT id,title FROM posts;
 id |     title                       
----+-----------------
  1 | {"en": "hello"}
  2 | {"en": "world"}
```

By default, generator will create a migration with 'gin' index on translateable field. If you you need to use custom path index you have to change it manually.

### Queries

You'll probably want to create scopes for this kind of queries.

```ruby
# get posts where `title` with `en` locale is 'hello'
Post.where("title->>'en' = ?", 'hello')

# get posts where `title` is 'hola' with any locale
Post.where("EXISTS (SELECT 1 FROM jsonb_each_text(posts.title) j WHERE j.value = ?)", 'hola')

# get posts where `title` LIKE 'прив' with any locale ignoring case
where("EXISTS (SELECT 1 FROM jsonb_each_text(posts.title) j WHERE lower(j.value) LIKE ?)", '%прив%')
```

I use this concern:
```ruby
# app/models/concerns/jsonb_querable
module JsonbQuerable
  extend ActiveSupport::Concern

  included do
    # http://stackoverflow.com/questions/36250331/query-postgres-jsonb-by-value-regardless-of-keys/36251296#36251296
    scope :where_jsonb_value, -> (attribute, value) {
      ta = sanitize("#{table_name}.#{attribute}")[1..-2]
      where("EXISTS (SELECT 1 FROM jsonb_each_text(#{ta}) j WHERE j.value = ?)", value)
    }

    scope :where_jsonb_value_like, -> (attribute, value, case_sens = false) {
      ta = sanitize("#{table_name}.#{attribute}")[1..-2]
      if case_sens
        where("EXISTS (SELECT 1 FROM jsonb_each_text(#{ta}) j WHERE j.value LIKE ?)", "%#{value}%")
      else
        where("EXISTS (SELECT 1 FROM jsonb_each_text(#{ta}) j WHERE lower(j.value) LIKE lower(?))", "%#{value}%")
      end
    }
  end
end
```

Refer to the [Postgres documentation](http://www.postgresql.org/docs/9.4/static/functions-json.html).

### Troubleshooting

If you're having problems with `translateable_sanity_check` due to non-existing database upon loading, you can disable those checks vie environment variable `DISABLE_TRANSLATEABLE_SANITY_CHECK=true` or by specifying `sanity_checks: false`, for example `translateable :title, sanity_checks: false`.

## TODO

- Add options (fallback locales lookup behavior maybe?)
- More clever database management for testing (temp schema or similar)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/olegantonyan/translateable. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
