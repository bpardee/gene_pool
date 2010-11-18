require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'gene_pool'
require 'stringio'
require 'logger'
require 'timeout'

# Increase visibility
class GenePool
  attr_reader :connections, :checked_out, :with_map
end

class DummyConnection
  attr_reader :count
  def initialize(count, sleep_time=nil)
    sleep sleep_time if sleep_time
    @count = count
    @closed = false
  end
  
  def to_s
    @count.to_s
  end

  def fail_on(*counts)
    raise Exception.new("Dummy exception on count #{@count}") if counts.include?(@count)
  end

  def close
    @closed = true
  end

  def closed?
    @closed
  end
end
    

class GenePoolTest < Test::Unit::TestCase

  context 'on default setup' do
    setup do
      @gene_pool = GenePool.new { Object.new }
    end

    should 'have default options set' do
      assert_equal 'GenePool', @gene_pool.name
      assert_equal 1,          @gene_pool.pool_size
      assert_equal 5.0,        @gene_pool.warn_timeout
      assert_nil               @gene_pool.logger
    end
  end
  
  context '' do
    setup do
      #@stringio = StringIO.new
      #@logger = Logger.new($stdout)
      #@logger = Logger.new(@stringio)
      @logger = nil
      # Override sleep in individual tests
      @sleep = nil
      counter = 0
      mutex = Mutex.new
      @gene_pool = GenePool.new(:name         => 'TestGenePool',
                                :pool_size    => 10,
                                :warn_timeout => 2.0,
                                :logger       => @logger) do
        count = nil
        mutex.synchronize do
          count = counter += 1
        end
        DummyConnection.new(count, @sleep)
      end
    end

    should 'have options set' do
      assert_equal 'TestGenePool', @gene_pool.name
      assert_equal 10,            @gene_pool.pool_size
      assert_equal 2.0,            @gene_pool.warn_timeout
      assert_same  @logger,        @gene_pool.logger
    end

    should 'create 1 connection' do
      (1..3).each do |i|
        @gene_pool.with_connection do |conn|
          assert_equal conn.count, 1
          assert_equal 1,         @gene_pool.connections.size
          assert_equal 1,         @gene_pool.checked_out.size
          assert_same  conn,      @gene_pool.connections[0]
          assert_same  conn,      @gene_pool.checked_out[0]
        end
        assert_equal 0, @gene_pool.checked_out.size
      end
    end
  
    should 'create 2 connections' do
      conn1 = @gene_pool.checkout
      (1..3).each do |i|
        @gene_pool.with_connection do |conn2|
          assert_equal 1, conn1.count
          assert_equal 2, conn2.count
          assert_equal 2, @gene_pool.connections.size
          assert_equal 2, @gene_pool.checked_out.size
          assert_same  conn1, @gene_pool.connections[0]
          assert_same  conn1, @gene_pool.checked_out[0]
          assert_same  conn2, @gene_pool.connections[1]
          assert_same  conn2, @gene_pool.checked_out[1]
        end
        assert_equal 1, @gene_pool.checked_out.size
      end
      @gene_pool.checkin(conn1)
      assert_equal 0, @gene_pool.checked_out.size
    end
  
    should 'be able to reset multiple times' do
      @gene_pool.with_connection do |conn1|
        conn2 = @gene_pool.renew(conn1)
        conn3 = @gene_pool.renew(conn2)
        assert_equal 1, conn1.count
        assert_equal 2, conn2.count
        assert_equal 3, conn3.count
        assert_equal 1, @gene_pool.connections.size
        assert_equal 1, @gene_pool.checked_out.size
      end
      assert_equal 1, @gene_pool.connections.size
      assert_equal 0, @gene_pool.checked_out.size
    end
  
    should 'be able to remove connection' do
      @gene_pool.with_connection do |conn|
        @gene_pool.remove(conn)
        assert_equal 0, @gene_pool.connections.size
        assert_equal 0, @gene_pool.checked_out.size
      end
      assert_equal 0, @gene_pool.connections.size
      assert_equal 0, @gene_pool.checked_out.size
    end
  
    should 'be able to remove multiple connections' do
      @gene_pool.with_connection do |conn1|
        @gene_pool.with_connection do |conn2|
          @gene_pool.with_connection do |conn3|
            @gene_pool.remove(conn1)
            @gene_pool.remove(conn3)
            assert_equal 1, @gene_pool.connections.size
            assert_equal 1, @gene_pool.checked_out.size
            assert_same  conn2, @gene_pool.checked_out[0]
            assert_same  conn2, @gene_pool.connections[0]
          end
          assert_equal 1, @gene_pool.connections.size
          assert_equal 1, @gene_pool.checked_out.size
        end
        assert_equal 1, @gene_pool.connections.size
        assert_equal 0, @gene_pool.checked_out.size
      end
      assert_equal 1, @gene_pool.connections.size
      assert_equal 0, @gene_pool.checked_out.size
    end
  
    should 'handle aborted connection' do
      @gene_pool.with_connection do |conn1|
        @sleep = 2
        e = assert_raises Timeout::Error do
          Timeout.timeout(1) do
            @gene_pool.with_connection { |conn2| }
          end
        end
        assert_equal 1, @gene_pool.connections.size
        assert_equal 1, @gene_pool.checked_out.size
      end
      assert_equal 1, @gene_pool.connections.size
      assert_equal 0, @gene_pool.checked_out.size
      # Do another test just to be sure nothings hosed
      @sleep = nil
      @gene_pool.with_connection do |conn1|
        assert 1, conn1.count
        @gene_pool.with_connection do |conn2|
          assert 3, conn2.count
        end
      end
    end
  
    should 'not allow more than pool_size connections' do
      conns = []
      pool_size = @gene_pool.pool_size
      (1..pool_size).each do |i|
        c = @gene_pool.checkout
        conns << c
        assert_equal i, c.count
        assert_equal i, @gene_pool.connections.size
        assert_equal i, @gene_pool.checked_out.size
        assert_equal conns, @gene_pool.connections
      end
      begin
        Timeout.timeout(1) do
          @gene_pool.checkout
        end
        flunk "connection should have timed out"
      rescue  Timeout::Error => e
        #pass "successfully timed out connection"
      end
      (1..pool_size).each do |i|
        @gene_pool.checkin(conns[i-1])
        assert_equal pool_size,   @gene_pool.connections.size
        assert_equal pool_size-i, @gene_pool.checked_out.size
      end
    end

    should 'handle thread contention' do
      conns = []
      pool_size = @gene_pool.pool_size
      # Do it with new connections and old connections
      (1..2).each do |n|
        (1..pool_size).each do |i|
          Thread.new do
            c = @gene_pool.checkout
            conns[i-1] = c
          end
        end
        # Let the threads complete
        sleep 1
        assert_equal pool_size,   @gene_pool.connections.size
        assert_equal pool_size,   @gene_pool.checked_out.size
        (1..pool_size).each do |i|
          Thread.new do
            @gene_pool.checkin(conns[i-1])
          end
        end
        sleep 1
        assert_equal pool_size, @gene_pool.connections.size
        assert_equal 0,         @gene_pool.checked_out.size
      end
      ival_conns = []
      @gene_pool.each { |conn| ival_conns << conn.count }
      ival_conns.sort!
      assert_equal (1..pool_size).to_a, ival_conns
    end

    should 'be able to auto-retry connection' do
      i = 1
      [false, true].each do |stat|
        conns = []
        @gene_pool.with_connection_auto_retry(stat) do |conn|
          conns << conn
          conn.fail_on(i)
          assert_equal 1, @gene_pool.connections.size
          assert_equal 1, @gene_pool.checked_out.size
          assert_equal i+1, conn.count
        end
        assert_equal stat, conns[0].closed?
        assert !conns[1].closed?
        i += 1
      end
      assert_equal 1, @gene_pool.connections.size
      assert_equal 0, @gene_pool.checked_out.size
    end

    should 'fail with auto-retry on double failure' do
      e = assert_raises Exception do
        @gene_pool.with_connection_auto_retry(false) do |conn|
          conn.fail_on(1,2)
        end
      end
      assert_match %r%Dummy exception%, e.message
      assert_equal 0, @gene_pool.connections.size
      assert_equal 0, @gene_pool.checked_out.size
      @gene_pool.with_connection do |conn|
        assert_equal 3, conn.count
      end
    end

    should 'not auto-retry on timeout' do
      e = assert_raises Timeout::Error do
        Timeout.timeout(1) do
          @gene_pool.with_connection_auto_retry do |conn|
            sleep 2
            assert false, true
          end
        end
      end
      assert_equal 0, @gene_pool.connections.size
      assert_equal 0, @gene_pool.checked_out.size
      @sleep = 0
      @gene_pool.with_connection_auto_retry do |conn|
        assert_equal 2, conn.count
        assert_equal 1, @gene_pool.checked_out.size
      end
      assert_equal 1, @gene_pool.connections.size
      assert_equal 0, @gene_pool.checked_out.size
    end
  end
end
