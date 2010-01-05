require File.dirname(__FILE__) + '/helper'

class ModelCachedTest < Test::Unit::TestCase
  def setup
    Rails.cache.clear
    User.send(:cache_by, :id, :email)
    $db = {
      1 => User.new(:id => 1, :email => 'Ary'),
      2 => User.new(:id => 2, :email => 'Nati')
    }
  end
  
  def test_should_define_methods
    user = $db[1]
    assert_equal true, user.respond_to?(:refresh_cache_by_id)
    assert_equal true, user.respond_to?(:refresh_cache_by_email)
    assert_equal true, User.respond_to?(:make_cache_key)
    assert_equal true, User.respond_to?(:find_by_id)
    assert_equal true, User.respond_to?(:find_by_email)
  end
  
  def test_make_cache_key
    user = $db[1]
    assert_equal 'users/email/Ary', user.class.make_cache_key('email', user.email)
  end
    
  def test_find_by_id_with_correct_data_when_not_in_cache
    assert_equal $db[1], User.find_by_id(1)
  end
  
  def test_find_by_id_with_correct_data_when_in_cache
    assert_equal nil, Rails.cache.read('users/id/1')
    assert_equal $db[1], User.find_by_id(1)
    assert_equal $db[1], Rails.cache.read('users/id/1')
  end
  
  def test_find_by_email_with_correct_data    
    assert_equal $db[1], User.find_by_email('Ary')
  end
  
  def test_find_by_email_with_correct_data_when_in_cache
    Rails.cache.write('users/email/Naty', $db[2])
    assert_equal $db[2], User.find_by_email('Nati')
  end
  
  def test_find_by_email_with_incorrect_data
    assert_equal nil, User.find_by_email('Djmal')
  end

  def test_should_refresh_cache_after_save
    user = $db[1]
    user.email = 'new_email'
    user.save
    assert_equal 'new_email', Rails.cache.read('users/id/1').try(:email)
  end
  
  def test_should_expire_cache_and_write_new_cache_when_keys_are_modified
    assert_equal nil, Rails.cache.read('users/email/Ary')
    user = User.find_by_email('Ary')
    user.email = 'new_email'
    user.save
    assert_equal nil, Rails.cache.read('users/email/Ary')
    assert_equal user, Rails.cache.read('users/email/new_email')
  end
end

class ModelCachedWithScopeTest < Test::Unit::TestCase
  def setup
    Rails.cache.clear
    User.send(:cache_by, :id, :email, :scope => :account_id)
    $db = {
      1 => User.new(:id => 1, :email => 'Ary',  :account_id => 1),
      2 => User.new(:id => 2, :email => 'Nati', :account_id => 1)
    }
  end
  
  def test_should_define_methods
    user = $db[1]
    assert_equal true, user.respond_to?(:refresh_cache_by_id)
    assert_equal true, user.respond_to?(:refresh_cache_by_email)
    assert_equal true, User.respond_to?(:make_cache_key)
    assert_equal true, User.respond_to?(:find_by_id)
    assert_equal true, User.respond_to?(:find_by_email)
  end
  
  def test_make_cache_key
    user = $db[1]
    assert_equal 'users/email/Ary/account_id:1', user.class.make_cache_key('email', user.email, user.cache_key_scope('account_id'))
  end
    
  def test_find_by_id_with_correct_data_when_not_in_cache
    assert_equal $db[1], current_account.users.find_by_id(1)
  end
  
  def test_find_by_id_with_correct_data_when_in_cache
    assert_equal nil, Rails.cache.read('users/id/1/account_id:1')
    assert_equal $db[1], current_account.users.find_by_id(1)
    assert_equal $db[1], Rails.cache.read('users/id/1/account_id:1')
  end
  
  def test_find_by_email_with_correct_data    
    assert_equal $db[1], current_account.users.find_by_email('Ary')
  end
  
  def test_find_by_email_with_correct_data_when_in_cache
    Rails.cache.write('users/email/Naty', $db[2])
    assert_equal $db[2], current_account.users.find_by_email('Nati')
  end
  
  def test_find_by_email_with_incorrect_data
    assert_equal nil, current_account.users.find_by_email('Djmal')
  end

  def test_should_refresh_cache_after_save
    user = $db[1]
    user.email = 'new_email'
    user.save
    assert_equal 'new_email', Rails.cache.read('users/id/1/account_id:1').try(:email)
  end
  
  def test_should_expire_cache_and_write_new_cache_when_keys_are_modified
    assert_equal nil, Rails.cache.read('users/email/Ary/account_id:1')
    user = current_account.users.find_by_email('Ary')
    user.email = 'new_email'
    user.save
    assert_equal nil, Rails.cache.read('users/email/Ary/account_id:1')
    assert_equal user, Rails.cache.read('users/email/new_email/account_id:1')
  end
end
