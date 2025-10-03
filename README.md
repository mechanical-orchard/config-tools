# ConfigTools

Tools for managing application config in Elixir apps

Implements a [Config.Provider](https://hexdocs.pm/elixir/main/Config.Provider.html) that will dump your config to stdout, allowing you to use it for approval testing.

# TODO

- [ ] example app(s) for integration testing and documentation
- [ ] a way to mask secrets
- [ ] flip dump / approve or make them separate commands - dump should come into the foreground more as a feature
- [ ] mix task(s0 entrypoint

# Example

Add the provider to your `mix.exs`

```
defp releases do
  [
    my_app: [
      config_providers: [
        ... your providers first
        {ConfigTools.Provider, nil}
...
```

Create a script to invoke the provider using a release:

```
# Switches that take you down different permutations of your config
export MIX_ENV=${argc_env:-prod}
export SECRETS_PROVIDER=${argc_hush:-env_var}
export CLOUD_PROVIDER=${argc_cloud:-aws}

# secrets required to start the app
export SENTRY_DSN=""
export SECRET_KEY_BASE=""

# build the release
mix release my_app --overwrite >/dev/null

# create a suffix for the approval dump file that includes relevant permutations
export CONFIG_APPROVE_SUFFIX="-${CLOUD_PROVIDER}"

# invoke the release, enabling the config provider
export CONFIG_APPROVE=check
export CONFIG_APPROVE_DUMP="${argc_dump:-}"
export CONFIG_AUTO_APPROVE="${argc_ok:-}"
output=$("_build/${MIX_ENV}/rel/mo/bin/my_app" eval ":null")
echo "$output"
if [[ "$output" == *"Config changed"* ]]; then
  exit 1
fi
```
