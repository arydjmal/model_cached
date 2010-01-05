begin
  require 'rubygems'
  require 'test/unit'
  require 'active_support'
  require 'memcache'
  require File.dirname(__FILE__) + '/../lib/model_cached'
rescue LoadError
  puts 'ModelCached tests rely on memcache, and active_support'
end

Object.send :include, ModelCached

module Rails
  def self.cache() $cache ||= ActiveSupport::Cache.lookup_store(:mem_cache_store); end
end

class User
  COLUMNS = %w( id email account_id )
  COLUMNS.each { |column| attr_accessor column }

  COLUMNS.each do |column|
    define_method "#{column}_changed?" do
      $db[id].send(column) != send(column)
    end
  end
  
  def self.before_save_callbacks() @before_save_callbacks ||= []; end
  def self.before_save(name) before_save_callbacks << name; end
  def self.after_save_callbacks() @after_save_callbacks ||= []; end
  def self.after_save(name) after_save_callbacks << name; end
  def self.scope(action, column) 1; end
  def self.users() self; end
  def initialize(params={}) params.each { |key, value| instance_variable_set("@#{key}", value) }; self; end
  def attributes() keys.inject({}) { |keys, key| keys.merge(key => send(key))}; end
  def keys() COLUMNS end
  def inspect() "\#<#{self.class.name} #{COLUMNS.map {|c| "#{c}: #{send(c).inspect}" }.join(', ')}>"; end
  
  def changes
    old = $db[id]
    COLUMNS.inject({}) { |changes, column| send("#{column}_changed?") ? changes.merge(column => [old.send(column), send(column)]) : changes }
  end
  
  def save
    self.class.before_save_callbacks.each { |callback| self.send(callback) }
    $db[id] = self
    self.class.after_save_callbacks.each { |callback| self.send(callback) }
  end

  def ==(other)
    return false unless other.respond_to? :attributes
    attributes == other.attributes
  end
  
  def self.find(*args) 
    options = args.last.is_a?(Hash) ? args.pop : {}

    if (ids = args.flatten).size > 1
      ids.map { |id| $db[id.to_i].clone }
    elsif (id = args.flatten.first).to_i.to_s == id.to_s
      $db[id.to_i].clone
    end
  end
  
  def self.first(options={})
    column, value = options[:conditions].to_a.first
    $db.detect { |record| record.last.send(column) == value }.try(:last).try(:clone)
  end
end

def current_account
  User
end
