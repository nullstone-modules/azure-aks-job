# 0.2.0 (Sep 30, 2026)
* Upgraded `nullstone-io/ns` provider to `~> 0.13.0`.
* Replaced `ns_env_variables` and `ns_secret_keys` with the layered `ns_env_layout`, `ns_env_values`, and `ns_env_platform_data` data sources to aggregate environment variables and secrets.
* Emitted the `env` platform data record, including the source of each variable and the Kubernetes secret key of each managed secret.
* Added support for `{{ k8s.field(...) }}`, `{{ k8s.configMap(...) }}`, `{{ k8s.resourceField(...) }}`, and `{{ k8s.fileKey(...) }}` in `env_vars`.

# 0.1.0 (Unreleased)
* Initial release
