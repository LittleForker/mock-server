require "sinatra/base"
require "logger"

class MockServer
  class App < Sinatra::Base
    use Rack::ShowExceptions
  end

  def initialize(app, port = 4000, &block)
    @app = app
    @port = port
  end

  def start
    Thread.new do
      with_quiet_logger do |logger|
        Rack::Handler::WEBrick.run(@app, :Port => @port, :Logger => logger, :AccessLog => [])
      end
    end

    wait_for_service("0.0.0.0", @port)

    self
  end

  module Methods
    def mock_server(*args, &block)
      app = Class.new(Sinatra::Base)
      app.class_eval(&block)
      @server = MockServer.new(app, *args, &block).start
    end
  end

protected
  def with_quiet_logger
    io = File.open("/dev/null", "w")
    yield(::Logger.new(io))
  ensure
    io.close
  end

  def listening?(host, port)
    begin
      socket = TCPSocket.new(host, port)
      socket.close unless socket.nil?
      true
    rescue Errno::ECONNREFUSED,
      Errno::EBADF,           # Windows
      Errno::EADDRNOTAVAIL    # Windows
      false
    end
  end

  def wait_for_service(host, port, timeout = 5)
    start_time = Time.now

    until listening?(host, port)
      if timeout && (Time.now > (start_time + timeout))
        raise SocketError.new("Socket did not open within #{timeout} seconds")
      end
    end

    true
  end
end
