require 'spec_helper'
require 'tmpdir'
require 'rails'
require 'generators/translateable/migration_generator'

describe Translateable::MigrationGenerator do
  let(:connection) { ActiveRecord::Base.connection }
  let(:model) { Class.new(ActiveRecord::Base) { self.table_name = 'blog_posts' } }

  around do |example|
    Dir.mktmpdir do |dir|
      @destination = dir
      example.run
    ensure
      connection.drop_table(:blog_posts, if_exists: true)
      Object.send(:remove_const, :MigrateTranslateableBlogPostsTitle) if defined?(MigrateTranslateableBlogPostsTitle)
    end
  end

  def create_blog_posts(index:)
    connection.create_table(:blog_posts) { |t| t.string :title, null: false, default: '' }
    connection.add_index(:blog_posts, :title) if index
    model.create!(title: 'hello')
    model.create!(title: 'world')
  end

  def generate(*args)
    described_class.start([*args, '--quiet'], destination_root: @destination)
    files = Dir[File.join(@destination, 'db/migrate/*.rb')]
    expect(files.size).to eq 1
    load files.first
    MigrateTranslateableBlogPostsTitle.new
  end

  def titles
    model.reset_column_information
    model.order(:id).pluck(:title)
  end

  def title_index
    connection.indexes(:blog_posts).find { |i| i.columns == ['title'] }
  end

  it 'migrates string data into locale hash and back' do
    create_blog_posts(index: false)
    migration = generate('blog_posts', 'title', 'pt-BR')

    migration.migrate(:up)
    expect(model.tap(&:reset_column_information).columns_hash['title'].type).to eq :jsonb
    expect(titles).to eq [{ 'pt-BR' => 'hello' }, { 'pt-BR' => 'world' }]
    expect(title_index).to be_nil

    model.create!(title: { en: 'no pt-BR here' })
    migration.migrate(:down)
    expect(model.tap(&:reset_column_information).columns_hash['title'].type).to eq :string
    expect(titles).to eq ['hello', 'world', '']
    expect(title_index).to be_nil
  end

  it 'uses default locale when none given' do
    create_blog_posts(index: false)
    generate('blog_posts', 'title').migrate(:up)

    expect(titles).to eq [{ 'en' => 'hello' }, { 'en' => 'world' }]
  end

  it 'recreates existing index as gin and restores it on rollback' do
    create_blog_posts(index: true)
    migration = generate('blog_posts', 'title', 'en')

    migration.migrate(:up)
    expect(title_index.using).to eq :gin

    migration.migrate(:down)
    expect(title_index.using).to eq :btree
  end

  it 'rejects unavailable locale' do
    create_blog_posts(index: false)
    expect { described_class.start(%w(blog_posts title xx --quiet), destination_root: @destination) }.to raise_error(ArgumentError, /xx/)
  end
end
