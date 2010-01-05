module ModelCached
  def self.included(base)
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    def cache_by(*column_names)
      options = column_names.extract_options!
      scope = options[:scope].inspect
      
      column_names.each do |column|
        inspected_column = column.to_s.inspect
        
        class_eval %{
          before_save :expire_cache_by_#{column}_if_modified
          after_save  :refresh_cache_by_#{column}
          
          def self.find_by_#{column}(value)
            find_cached_by(#{inspected_column}, value, #{scope})
          end
          
          def expire_cache_by_#{column}_if_modified
            expire_cache_by(#{inspected_column}, #{scope})
          end
          
          def refresh_cache_by_#{column}
            refresh_cache_by(#{inspected_column}, #{scope})
          end
        }, __FILE__, __LINE__
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
      if send("#{column}_changed?")
        Rails.cache.delete(self.class.make_cache_key(column, changes[column].first, cache_key_scope(scope)))
      end
    end
    
    def cache_key_scope(scope=nil)
      "#{scope}:#{self.send(scope)}" if scope
    end
  end
end
