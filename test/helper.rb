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

module ActiveRecord
  class RecordNotFound < StandardError; end
end

class User
  COLUMNS = %w( id email account_id deleted )
  COLUMNS.each { |column| attr_accessor column }

  COLUMNS.each do |column|
    define_method "#{column}_changed?" do
      $db[id].send(column) != send(column)
    end
  end
  
  HOOKS = %w( before_save before_update before_destroy after_save after_update after_destroy )
  HOOKS.each do |hook|
    class_eval %{
      def self.#{hook}_callbacks() @#{hook}_callbacks ||= []; end
      def self.#{hook}(*args) #{hook}_callbacks << args; end
    }, __FILE__, __LINE__
  end

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
    run_callbacks(self.class.before_save_callbacks)
    run_callbacks(self.class.before_update_callbacks)
    $db[id] = self
    run_callbacks(self.class.after_save_callbacks)
    run_callbacks(self.class.after_update_callbacks)
  end
  
  def destroy
    run_callbacks(self.class.before_destroy_callbacks)
    $db.delete(id)
    run_callbacks(self.class.after_destroy_callbacks)
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
  
  private
  
  def run_callbacks(callbacks)
    callbacks.each do |callback, options|
      self.send(callback) if !options || !options[:if] || send(options[:if])
    end
  end
end

def current_account
  User
end
