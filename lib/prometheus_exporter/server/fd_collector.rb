# frozen_string_literal: true

module PrometheusExporter::Server
  class FdCollector < TypeCollector
    def initialize
      @metrics = {}
    end

    def type
      "fd"
    end

    def collect(obj)
      ensure_metrics
      observe(obj)
    end

    def metrics
      @metrics.values
    end

    protected

    def ensure_metrics
      unless @http_requests
        @metrics["http_requests"] = @http_requests = PrometheusExporter::Metric::Counter.new(
          "http_requests_total",
          "Total HTTP requests from web app."
        )

        @metrics["http_duration_seconds"] = @http_duration_seconds = PrometheusExporter::Metric::FdSummary.new(
          "http_duration_seconds",
          "Time spent in HTTP reqs in seconds."
        )
      end
    end

    def observe(obj)

      labels = {
        controller: obj["controller"] || "other",
        action: obj["action"] || "other",
        site_id: obj["site_id"] || "-"
      }

      @http_requests.observe(1, labels.merge(status: obj["status"]))

      if timings = obj["timings"]
        @http_duration_seconds.observe(timings["total_duration"], labels)
      end
    end
  end
end
