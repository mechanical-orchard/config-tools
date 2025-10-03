defmodule ConfigTools.Provider do
  @moduledoc """
  Uses "approval testing" or "golden master" to check the config
  for drift. Useful during refactoring of runtime.exs files.
  """

  @behaviour Config.Provider

  defmodule Options do
    @moduledoc false
    defstruct [:approve?, :dump?, :release_root, :suffix, :auto_approve?]

    def from_env(%Options{} = opts) do
      %Options{
        release_root: opts.release_root || System.get_env("RELEASE_ROOT"),
        suffix: opts.suffix || System.get_env("CONFIG_APPROVE_SUFFIX"),
        approve?: opts.approve? || System.get_env("CONFIG_APPROVE"),
        dump?: opts.dump? || String.trim(System.get_env("CONFIG_APPROVE_DUMP", "")) != "",
        auto_approve?:
          opts.auto_approve? || String.trim(System.get_env("CONFIG_AUTO_APPROVE", "")) != ""
      }
    end
  end

  @impl Config.Provider
  def init(_opts), do: %Options{}

  @impl Config.Provider
  def load(config, opts) do
    opts = Options.from_env(opts)

    if opts.approve? && !opts.dump? do
      IO.puts("Checking config against previous state...")

      approve(
        normalize(config),
        normalize(read_previous_config_from_file(opts)),
        opts
      )
    end

    if opts.dump? do
      dump_config_to_stdout(config)
    end

    config
  end

  def approve(new_config, [], opts) do
    write_config_to_file(new_config, opts)
  end

  def approve(new_config, previous_config, opts) do
    if new_config == previous_config do
      IO.puts("✅ config unchanged")
    else
      if opts.auto_approve? do
        IO.puts("Config changed, auto-approving...")
        write_config_to_file(new_config, opts)
      else
        dir = System.tmp_dir!()
        dump_config_to_file(previous_config, "#{dir}/previous_config")
        dump_config_to_file(new_config, "#{dir}/new_config")

        {diff, _} =
          System.cmd("diff", [
            "--color=always",
            "-y",
            "#{dir}/previous_config",
            "#{dir}/new_config"
          ])

        IO.puts("Config changed:")
        IO.puts(diff)
      end
    end
  end

  defp normalize(config) when is_list(config) do
    config |> Keyword.to_list() |> Enum.sort()
  end

  defp read_previous_config_from_file(opts) do
    path = path(opts)

    if File.exists?(path) do
      IO.puts("Reading previous config state from file #{path}")
      :erlang.binary_to_term(File.read!(path))
    else
      IO.puts("No previous config state file found at #{path}")
      []
    end
  end

  defp dump_config_to_file(config, path) do
    config
    |> inspect(pretty: true, limit: :infinity)
    |> then(&"#{&1}\n")
    |> then(&File.write!(path, &1))
  end

  defp dump_config_to_stdout(config) do
    config
    |> inspect(pretty: true, limit: :infinity, syntax_colors: IO.ANSI.syntax_colors())
    |> IO.puts()
  end

  defp write_config_to_file(config, opts) do
    File.write!(path(opts), :erlang.term_to_binary(config))
    IO.puts("Config state successfully written to #{path(opts)}")
  end

  def path(opts) do
    release_root = opts.release_root
    Path.join(release_root, ["config-dump", suffix(opts)])
  end

  defp suffix(opts), do: opts.suffix
end
