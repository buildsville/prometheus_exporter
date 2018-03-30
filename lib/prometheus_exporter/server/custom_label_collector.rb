# frozen_string_literal: true

module PrometheusExporter::Server
  class CustomLabelCollector < TypeCollector
    def initialize
      @metrics = {}
    end

    def type
      "custom"
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
      unless @http_duration_seconds
        @metrics["http_duration_seconds"] = @http_duration_seconds = PrometheusExporter::Metric::CustomLabelMetric.new(
          "http_duration_seconds",
          "Time spent in HTTP reqs in seconds."
        )
      end
    end

    def observe(obj)

      labels = {
        status: obj["status"] || "unknown"
      }
      $customlabel.each do |l|
        labels[l.to_sym] = obj[l] || "unknown"
      end

      if timings = obj["timings"]
        @http_duration_seconds.observe(timings["total_duration"], labels)
      end
    end
  end
end
