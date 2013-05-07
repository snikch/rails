# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlUUIDTest < ActiveRecord::TestCase
  class UUID < ActiveRecord::Base
    self.table_name = 'pg_uuids'
  end

  def setup
    @connection = ActiveRecord::Base.connection

    unless @connection.supports_extensions?
      return skip "do not test on PG without uuid-ossp"
    end

    unless @connection.extension_enabled?('uuid-ossp')
      @connection.enable_extension 'uuid-ossp'
      @connection.commit_db_transaction
    end

    @connection.reconnect!

    @connection.transaction do
      @connection.create_table('pg_uuids', id: :uuid) do |t|
        t.string 'name'
        t.uuid 'other_uuid', default: 'uuid_generate_v4()'
      end
    end
  end

  def teardown
    @connection.execute 'drop table if exists pg_uuids'
  end

  def test_id_is_uuid
    assert_equal :uuid, UUID.columns_hash['id'].type
    assert UUID.primary_key
  end

  def test_id_has_a_default
    u = UUID.create
    assert_not_nil u.id
  end

  def test_auto_create_uuid
    u = UUID.create
    u.reload
    assert_not_nil u.other_uuid
  end
end

class PostgresqlUUIDTestInverseOf < ActiveRecord::TestCase
  class UuidPost < ActiveRecord::Base
    self.table_name = 'pg_uuid_posts'
    has_many :uuid_comments, inverse_of: :uuid_post
  end

  class UuidComment < ActiveRecord::Base
    self.table_name = 'pg_uuid_comments'
    belongs_to :uuid_post
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.reconnect!

    @connection.transaction do
      @connection.create_table('pg_uuid_posts', id: :uuid) do |t|
        t.string 'title'
      end
      @connection.create_table('pg_uuid_comments', id: :uuid) do |t|
        t.uuid :uuid_post_id, default: 'uuid_generate_v4()'
        t.string 'content'
      end
    end
  end

  def teardown
    @connection.transaction do
      @connection.execute 'drop table if exists pg_uuid_comments'
      @connection.execute 'drop table if exists pg_uuid_posts'
    end
  end

  def test_collection_association_with_uuid
    post    = UuidPost.create!
    comment = post.uuid_comments.create!
    assert post.uuid_comments.find(comment.id)
  end
end
