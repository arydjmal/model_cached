module ModelCached
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def cache_by(*column_names)
      options = { :logical_delete => :deleted? }.merge(column_names.extract_options!)
      scope = options.delete(:scope).inspect
      
      column_names.each do |column|
        inspected_column = column.to_s.inspect
        
        class_eval %{
          before_update :set_old_cache_to_delete_by_#{column}, :if => :#{column}_changed?
          after_update  :expire_old_cache_by_#{column},        :if => :old_cache_to_delete_by_#{column}
          after_save    :refresh_or_expire_cache_by_#{column}
          after_destroy :expire_cache_by_#{column}
          
          def self.find_by_#{column}(value)
            find_cached_by(#{inspected_column}, value, #{scope})
          end
          
          def set_old_cache_to_delete_by_#{column}
            @old_cache_to_delete_by_#{column} = self.class.make_cache_key(#{inspected_column}, changes[#{inspected_column}].first, cache_key_scope(#{scope}))
          end
          
          def old_cache_to_delete_by_#{column}
            @old_cache_to_delete_by_#{column}
          end
          
          def expire_old_cache_by_#{column}
            Rails.cache.delete(old_cache_to_delete_by_#{column})
          end
          
          def refresh_or_expire_cache_by_#{column}
            if respond_to?(#{options[:logical_delete].to_s.inspect}) && send(#{options[:logical_delete].to_s.inspect})
              expire_cache_by_#{column}
            else
              refresh_cache_by_#{column}
            end
          end
          
          def expire_cache_by_#{column}
            expire_cache_by(#{inspected_column}, #{scope})
          end
          
          def refresh_cache_by_#{column}
            refresh_cache_by(#{inspected_column}, #{scope})
          end
        }, __FILE__, __LINE__
      end
      
      if column_names.include?(:id)
        class_eval %{
          def self.find(*args)
            if (id = args.first).is_a?(Integer)
              find_by_id(id) || raise(ActiveRecord::RecordNotFound, "Couldn't find \#{name} with ID=\#{id}")
            else
              super(args)
            end
          end
        }
      end
      
      include ModelCached::InstanceMethods
    end
    
    def find_cached_by(column, value, scope)
      if scope && !cache_key_scope(scope)
        first(:conditions => {column => value})
      else
        Rails.cache.fetch(make_cache_key(column, value, cache_key_scope(scope))) { first(:conditions => {column => value}) }
      end
    end

    def cache_key_scope(scope=nil)
      if scope && scope_value = self.scope(:create, scope)
        "#{scope}:#{scope_value}"
      end
    end

    def make_cache_key(*args)
      args.unshift(self.name.tableize).compact.join('/').gsub(/\s+/, '+')
    end
  end
  
  module InstanceMethods
    def refresh_cache_by(column, scope)
      Rails.cache.write(self.class.make_cache_key(column, self.send(column), cache_key_scope(scope)), self)
    end
    
    def expire_cache_by(column, scope)
      Rails.cache.delete(self.class.make_cache_key(column, self.send(column), cache_key_scope(scope)))
    end
    
    def cache_key_scope(scope=nil)
      "#{scope}:#{self.send(scope)}" if scope
    end
  end
end
