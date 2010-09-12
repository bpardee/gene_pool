# Generic connection pool class
class GenePool

  attr_reader :name, :pool_size, :warn_timeout, :logger

  def initialize(options={}, &connect_block)
    @connect_block = connect_block

    @name         = options[:name]         || 'GenePool'
    @pool_size    = options[:pool_size]    || 1
    @warn_timeout = options[:warn_timeout] || 5.0
    @logger       = options[:logger]

    # Mutex for synchronizing pool access
    @mutex = Mutex.new

    # Condition variable for waiting for an available connection
    @queue = ConditionVariable.new

    @connections = []
    @checked_out = []
    # Map the original connections object_id within the with_connection method to the final connection.
    # This could change if the connection is renew'ed.
    @with_map    = {}
  end

  # Check out a connection from the pool, creating it if necessary.
  def checkout
    start_time = Time.now
    connection = nil
    reserved_connection_placeholder = Thread.current
    begin
      @mutex.synchronize do
        until connection do
          if @checked_out.size < @connections.size
            connection = (@connections - @checked_out).first
            @checked_out << connection
          elsif @connections.size < @pool_size
            # Perform the actual connection outside the mutex
            connection = reserved_connection_placeholder
            @connections << connection
            @checked_out << connection
            @logger.debug "#{@name}: Created connection ##{@connections.size} #{connection}:#{connection.object_id} for #{name}" if @logger && @logger.debug?
          else
            @logger.info "#{@name}: Waiting for an available connection, all #{@pool_size} connections are checked out." if @logger
            @queue.wait(@mutex)
          end
        end
      end
    ensure
      delta = Time.now - start_time
      if @logger && delta > @warn_timeout
        @logger.warn "#{@name}: It took #{delta} seconds to obtain a connection.  Consider raising the pool size which is " +
          "currently set to #{@pool_size}."
      end
    end
    if connection == reserved_connection_placeholder
      connection = renew(reserved_connection_placeholder)
    end
    
    @logger.debug "#{@name}: Checkout connection #{connection.object_id} self=#{dump}" if @logger && @logger.debug?
    return connection
  end

  # Return a connection to the pool.
  def checkin(connection)
    @mutex.synchronize do
      @checked_out.delete(connection)
      @queue.signal
    end
    @logger.debug "#{@name}: Checkin connection #{connection.object_id} self=#{dump}" if @logger && @logger.debug?
  end
  
  # Create a scope for checking out a connection
  def with_connection
    connection = checkout
    @mutex.synchronize do
      @with_map[connection.object_id] = connection
    end
    begin
      yield connection
    ensure
      @mutex.synchronize do
        # Update connection for any renew's that have occurred
        connection = @with_map.delete(connection.object_id)
      end
      checkin(connection)
    end
  end
  
  # Remove an existing connection from the pool
  def remove(connection)
    @mutex.synchronize do
      @connections.delete(connection)
      @checked_out.delete(connection)
      @queue.signal
    end
    @logger.debug "#{@name}: Removed connection #{connection.object_id} self=#{dump}" if @logger && @logger.debug?
  end

  # If a connection needs to be renewed for some reason, reassign it here
  def renew(old_connection)
    new_connection =
      begin
        @connect_block.call
      rescue Exception
        remove old_connection
        raise
      end
    @mutex.synchronize do
      index = @checked_out.index(old_connection)
      raise Error.new("Can't reassign non-checked out connection for #{@name}") unless index
      @checked_out[index] = new_connection
      @connections[@connections.index(old_connection)] = new_connection
      # If this is part of a with_connection block, then track our new connection
      with_key = @with_map.index(old_connection)
      @with_map[with_key] = new_connection if with_key
    end
    @logger.debug "#{@name}: Renewed connection old=#{old_connection.object_id} new=#{new_connection}:#{new_connection.object_id}" if @logger && @logger.debug?
    return new_connection
  end
  
  # Perform the given block for each connection, i.e., closing each connection.
  def each
    @mutex.synchronize do
      @connections.each { |connection| yield connection }
    end
  end
  
  private
  
  def dump
    conn = chk = with = nil
    @mutex.synchronize do
      conn = @connections.map{|c| c.object_id}.join(',')
      chk  = @checked_out.map{|c| c.object_id}.join(',')
      with = @with_map.keys.map{|k| "#{k}=#{@with_map[k].object_id}"}.join(',')
    end
    "connections=#{conn} checked_out=#{chk} with_map=#{with}"
  end
end
