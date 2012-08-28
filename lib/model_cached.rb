module ModelCached
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def cache_by(*column_names)
      options = {logical_delete: nil, scope: nil}.merge(column_names.extract_options!)
      options[:columns] = column_names
      after_save :refresh_mc_keys
      after_destroy :expire_mc_keys
      class_eval %{ def self.mc_options; #{options}; end }
      column_names.each do |column|
        class_eval %{ def self.find_by_#{column}(value); find_cached_by(#{column.to_s.inspect}, value); end }
      end
      if column_names.include?(:id)
        class_eval do
          def self.find(*args)
            if args.size == 1 && (id = args.first).is_a?(Integer)
              find_by_id(id) || raise(ActiveRecord::RecordNotFound, "Couldn't find #{name} with ID=#{id}")
            else
              super(*args)
            end
          end
        end
      end
      include ModelCached::InstanceMethods
    end

    def find_cached_by(column, value)
      if mc_options[:scope] and mc_scope_key.nil?
        where(column => value).first
      else
        Rails.cache.fetch(mc_key(column, value)) { where(column => value).first }
      end
    end

    def mc_scope_key
      self.new().mc_scope_key
    end

    def mc_key(column, value, scope_key=nil)
      [column, value, scope_key || mc_scope_key].unshift(self.name.tableize).compact.join('/').gsub(/\s+/, '+')
    end
  end

  module InstanceMethods
    def mc_columns; self.class.mc_options[:columns]; end
    def mc_scope; self.class.mc_options[:scope]; end
    def mc_logical_delete; self.class.mc_options[:logical_delete]; end

    def mc_key(column, value=nil)
      self.class.mc_key(column, value || self.send(column), mc_scope_key)
    end

    def mc_scope_key
      "#{mc_scope}:#{self.send(mc_scope)}" if mc_scope
    end

    def expire_mc_keys
      mc_columns.each do |column|
        Rails.cache.delete(mc_key(column))
      end
    end

    def refresh_mc_keys
      if mc_logical_delete && send(mc_logical_delete)
        expire_mc_keys
      else
        mc_columns.each do |column|
          Rails.cache.write(mc_key(column), self)
          if send("#{column}_changed?")
            Rails.cache.delete(mc_key(column, send("#{column}_was")))
          end
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, ModelCached)
