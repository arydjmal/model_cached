require 'helper'

class ModelCachedTest < Test::Unit::TestCase
  def setup
    User.delete_all
    User.send(:cache_by, :id, :email)
    @ary  = User.create!(:email => 'Ary')
    @nati = User.create!(:email => 'Nati')
    Rails.cache.clear
  end

  def test_make_cache_key
    assert_equal 'users/email/Ary', @ary.mc_key('email')
  end

  def test_find_with_correct_data_when_not_in_cache
    assert_equal nil, Rails.cache.read("users/id/#{@ary.id}")
    assert_equal @ary, User.find(@ary.id)
    assert_equal @ary, Rails.cache.read("users/id/#{@ary.id}")
  end

  def test_find_with_incorrect_data_when_not_in_cache
    assert_raise(ActiveRecord::RecordNotFound) do
      User.find(1234567890)
    end
  end

  def test_find_by_id_with_correct_data_when_not_in_cache
    assert_equal @ary, User.find_by_id(@ary.id)
  end

  def test_find_by_id_with_correct_data_when_in_cache
    assert_equal nil, Rails.cache.read("users/id/#{@ary.id}")
    assert_equal @ary, User.find_by_id(@ary.id)
    assert_equal @ary, Rails.cache.read("users/id/#{@ary.id}")
  end

  def test_find_by_email_with_correct_data
    assert_equal @ary, User.find_by_email('Ary')
  end

  def test_find_by_email_with_correct_data_when_in_cache
    Rails.cache.write('users/email/Naty', @nati)
    assert_equal @nati, User.find_by_email('Nati')
  end

  def test_find_by_email_with_incorrect_data
    assert_equal nil, User.find_by_email('Djmal')
  end

  def test_should_refresh_cache_after_save
    @ary.email = 'new_email'
    @ary.save
    assert_equal 'new_email', Rails.cache.read("users/id/#{@ary.id}").try(:email)
  end

  def test_should_expire_cache_and_write_new_cache_when_keys_are_modified
    assert_equal nil, Rails.cache.read('users/email/Ary')
    @ary = User.find_by_email('Ary')
    assert_equal @ary, Rails.cache.read('users/email/Ary')
    @ary.email = 'new_email'
    @ary.save
    assert_equal nil, Rails.cache.read('users/email/Ary')
    assert_equal @ary, Rails.cache.read('users/email/new_email')
  end

  def test_should_expire_cache_on_destroy
    assert_equal nil, Rails.cache.read("users/id/#{@ary.id}")
    @ary = User.find_by_id(@ary.id)
    assert_equal @ary, Rails.cache.read("users/id/#{@ary.id}")
    @ary.destroy
    assert_equal nil, Rails.cache.read("users/id/#{@ary.id}")
  end

  def test_refresh_should_not_happen_if_value_is_blank
    @ary.update_attributes!(email: '')
    assert_equal @ary, Rails.cache.read(@ary.mc_key(:id))
    assert_equal nil, Rails.cache.read(@ary.mc_key(:email))
  end
end

class ModelCachedWithScopeTest < Test::Unit::TestCase
  def setup
    User.delete_all
    User.send(:cache_by, :id, :email, :scope => :account_id)
    @account = Account.create!(:name => 'Natural Bits')
    @ary  = @account.users.create!(:email => 'Ary')
    @nati = @account.users.create!(:email => 'Nati')
    Rails.cache.clear
  end

  def test_make_cache_key
    assert_equal "users/email/Ary/account_id:#{@account.id}", @ary.mc_key('email')
  end

  def test_find_by_id_with_correct_data_when_not_in_cache
    assert_equal @ary, @account.users.find_by_id(@ary.id)
  end

  def test_find_by_id_with_correct_data_when_in_cache
    key = "users/id/#{@ary.id}/account_id:#{@account.id}"
    assert_equal nil, Rails.cache.read(key)
    @account.users.find_by_id(@ary.id)
    assert_equal @ary, Rails.cache.read(key)
  end

  def test_find_by_id_without_scoping
    key = "users/id/#{@ary.id}/account_id:#{@account.id}"
    assert_equal nil, Rails.cache.read(key)
    User.find_by_id(@ary.id)
    assert_equal nil, Rails.cache.read(key)
  end

  def test_find_by_email_with_correct_data    
    assert_equal @ary, @account.users.find_by_email('Ary')
  end

  def test_find_by_email_with_correct_data_when_in_cache
    Rails.cache.write('users/email/Naty', @nati)
    assert_equal @nati, @account.users.find_by_email('Nati')
  end

  def test_find_by_email_with_incorrect_data
    assert_equal nil, @account.users.find_by_email('Djmal')
  end

  def test_should_refresh_cache_after_save
    @ary.email = 'new_email'
    @ary.save
    assert_equal 'new_email', Rails.cache.read("users/id/#{@ary.id}/account_id:#{@account.id}").try(:email)
  end

  def test_should_expire_cache_and_write_new_cache_when_keys_are_modified
    assert_equal nil, Rails.cache.read("users/email/Ary/account_id:#{@account.id}")
    @ary = @account.users.find_by_email('Ary')
    @ary.email = 'new_email'
    @ary.save
    assert_equal nil, Rails.cache.read("users/email/Ary/account_id:#{@account.id}")
    assert_equal @ary, Rails.cache.read("users/email/new_email/account_id:#{@account.id}")
  end
end

class ModelCachedWithLogicalDeleteTest < Test::Unit::TestCase
  def setup
    User.delete_all
    User.send(:cache_by, :id, :logical_delete => :is_deleted?)
    User.class_eval { def is_deleted?() deleted == true; end }
    @ary  = User.create!(:email => 'Ary', :deleted => false)
    @nati = User.create!(:email => 'Nati', :deleted => false)
    Rails.cache.clear
  end

  def test_default_logical_delete
    assert_equal nil, Rails.cache.read("users/id/#{@ary.id}")
    @ary = User.find_by_id(@ary.id)
    assert_equal @ary, Rails.cache.read("users/id/#{@ary.id}")
    @ary.deleted = true
    @ary.save
    assert_equal nil, Rails.cache.read("users/id/#{@ary.id}")
  end
end
