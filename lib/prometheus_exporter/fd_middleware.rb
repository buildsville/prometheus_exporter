# frozen_string_literal: true

require 'prometheus_exporter/instrumentation/method_profiler'
require 'prometheus_exporter/client'

class PrometheusExporter::FdMiddleware
  MethodProfiler = PrometheusExporter::Instrumentation::MethodProfiler

  def initialize(app, config = { client: nil, site_id: nil })
    @app = app
    @client = config[:client] || PrometheusExporter::Client.default
    @site_id = config[:site_id] || -> (env){ '-' }
  end

  def call(env)
    queue_time = measure_queue_time(env)

    MethodProfiler.start
    result = @app.call(env)
    info = MethodProfiler.stop

    result
  ensure
    status = (result && result[0]) || -1
    params = env["action_dispatch.request.parameters"]
    action, controller, site_id = nil
    if params
      action = params["action"]
      controller = params["controller"]
    end
    site_id = @site_id.call(env)

    @client.send_json(
      type: "fd",
      timings: info,
      queue_time: queue_time,
      action: action,
      controller: controller,
      status: status,
      site_id: site_id
    )
  end

  private

  # measures the queue time (= time between receiving the request in downstream
  # load balancer and starting request in ruby process)
  def measure_queue_time(env)
    start_time = queue_start(env)

    return unless start_time

    queue_time = request_start.to_f - start_time.to_f
    queue_time unless queue_time.negative?
  end

  # need to use CLOCK_REALTIME, as nginx/apache write this also out as the unix timestamp
  def request_start
    Process.clock_gettime(Process::CLOCK_REALTIME)
  end

  # get the content of the x-queue-start or x-request-start header
  def queue_start(env)
    value = env['HTTP_X_REQUEST_START'] || env['HTTP_X_QUEUE_START']
    unless value.nil? || value == ''
      convert_header_to_ms(value.to_s)
    end
  end

  # nginx returns time as milliseconds with 3 decimal places
  # apache returns time as microseconds without decimal places
  # this method takes care to convert both into a proper second + fractions timestamp
  def convert_header_to_ms(str)
    str = str.gsub(/t=|\./, '')
    "#{str[0,10]}.#{str[10,13]}".to_f
  end
end
