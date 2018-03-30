# frozen_string_literal: true

module PrometheusExporter::Metric
  class CustomLabelMetric < Base
    attr_reader :data

    def initialize(name, help)
      super
      @data = Hash.new { |label,category| label[category] = {} }
    end

    def type
      "custom_label_metric"
    end

    def metric_text
      text = String.new
      first = true
      @data.each do |labels, values|
        text << "\n" unless first
        first = false
        text << "#{prefix(@name)}_sum#{labels_text(labels)} #{@data[labels][:sum]}\n"
        text << "#{prefix(@name)}_count#{labels_text(labels)} #{@data[labels][:count]}"
      end
      text
    end

    def observe(value, labels = {})
      @data[labels][:sum] ||= 0
      @data[labels][:count] ||= 0

      @data[labels][:sum] += value
      @data[labels][:count] += 1
    end
  end
end
