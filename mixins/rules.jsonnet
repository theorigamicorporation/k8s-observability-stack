// Rules generation from mixins
// This file is used by hack/generate-rules.sh

local config = import 'config.libsonnet';

// Import mixins if they exist
local kubernetesMixin = (import 'kubernetes-mixin/mixin.libsonnet') + {
  _config+:: config._config,
};

local nodeMixin = (import 'node-mixin/mixin.libsonnet') + {
  _config+:: config._config,
};

// Output structure
{
  // Prometheus/VMRule compatible format
  prometheusRules: kubernetesMixin.prometheusRules,
  prometheusAlerts: kubernetesMixin.prometheusAlerts,
  nodeRules: nodeMixin.prometheusRules,
  nodeAlerts: nodeMixin.prometheusAlerts,
}
