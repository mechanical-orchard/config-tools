defmodule ConfigTools.ProviderTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  alias ConfigTools.Provider
  alias ConfigTools.Provider.Options

  describe "load/2" do
    @tag :tmp_dir
    test "returns config unchanged when approve is false", %{tmp_dir: tmp_dir} do
      config = [app: [key: "value"]]

      opts = %Options{
        approve?: nil,
        dump?: false,
        release_root: tmp_dir,
        suffix: "test",
        auto_approve?: nil
      }

      output =
        capture_io(fn ->
          result = Provider.load(config, opts)
          assert result == config
        end)

      assert output == ""
    end

    @tag :tmp_dir
    test "returns config unchanged when dump is true", %{tmp_dir: tmp_dir} do
      config = [app: [key: "value"]]

      opts = %Options{
        approve?: "true",
        dump?: true,
        release_root: tmp_dir,
        suffix: "test",
        auto_approve?: nil
      }

      output =
        capture_io(fn ->
          result = Provider.load(config, opts)
          assert result == config
        end)

      # Should dump config to stdout
      assert output =~ "app:"
      assert output =~ "key:"
      assert output =~ "\"value\""
    end

    @tag :tmp_dir
    test "checks config against previous state when approve is true and dump is false", %{
      tmp_dir: tmp_dir
    } do
      config = [app: [key: "value"]]

      opts = %Options{
        approve?: "true",
        dump?: false,
        release_root: tmp_dir,
        suffix: "-test",
        auto_approve?: nil
      }

      config_path = Path.join(tmp_dir, "config-dump-test")
      File.mkdir_p!(Path.dirname(config_path))

      # Create a previous config that's different
      previous_config = [app: [key: "old_value"]]
      File.write!(config_path, :erlang.term_to_binary(previous_config))

      output =
        capture_io(fn ->
          result = Provider.load(config, opts)
          assert result == config
        end)

      expected_content = ~s"""
      Config changed:
      [app: [key: \"old_value\"]]\t\t\t\t      |\t[app: [key: \"value\"]]
      """

      assert remove_ansi(output) =~ expected_content
    end

    @tag :tmp_dir
    test "auto-approves config changes when auto_approve is true", %{tmp_dir: tmp_dir} do
      config = [app: [key: "new_value"]]
      previous_config = [app: [key: "old_value"]]

      opts = %Options{
        approve?: "true",
        dump?: false,
        auto_approve?: true,
        release_root: tmp_dir,
        suffix: "-test"
      }

      # Setup previous config file (path matches implementation: release_root + "config-dump" + suffix)
      config_path = Path.join(tmp_dir, "config-dump-test")
      File.mkdir_p!(Path.dirname(config_path))
      File.write!(config_path, :erlang.term_to_binary(previous_config))

      output =
        capture_io(fn ->
          result = Provider.load(config, opts)
          assert result == config
        end)

      assert output =~ "Checking config against previous state..."
      assert output =~ "Reading previous config state from file"
      assert output =~ "Config changed, auto-approving..."
      assert output =~ "Config state successfully written to"

      # Verify the new config was written to the file
      written_config = :erlang.binary_to_term(File.read!(config_path))
      assert written_config == config
    end

    @tag :tmp_dir
    test "shows config unchanged when config matches previous state", %{tmp_dir: tmp_dir} do
      config = [app: [key: "value"]]

      opts = %Options{
        approve?: "true",
        dump?: false,
        release_root: tmp_dir,
        suffix: "-test",
        auto_approve?: nil
      }

      config_path = Path.join(tmp_dir, "config-dump-test")
      File.mkdir_p!(Path.dirname(config_path))

      # Create a previous config that's the same
      File.write!(config_path, :erlang.term_to_binary(config))

      output =
        capture_io(fn ->
          result = Provider.load(config, opts)
          assert result == config
        end)

      assert output =~ "Checking config against previous state..."
      assert output =~ "Reading previous config state from file"
      assert output =~ "✅ config unchanged"
    end

    @tag :tmp_dir
    test "handles missing previous config file", %{tmp_dir: tmp_dir} do
      config = [app: [key: "value"]]

      opts = %Options{
        approve?: "true",
        dump?: false,
        release_root: tmp_dir,
        suffix: "nonexistent"
      }

      output =
        capture_io(fn ->
          result = Provider.load(config, opts)
          assert result == config
        end)

      assert output =~ "Checking config against previous state..."
      assert output =~ "No previous config state file found"
    end

    @tag :tmp_dir
    test "dumps config to stdout when dump option is set", %{tmp_dir: tmp_dir} do
      config = [app: [key: "value"], another_app: [setting: true]]

      opts = %Options{
        approve?: nil,
        dump?: true,
        release_root: tmp_dir,
        suffix: "test",
        auto_approve?: nil
      }

      output =
        capture_io(fn ->
          result = Provider.load(config, opts)
          assert result == config
        end)

      expected_content = "[app: [key: \"value\"], another_app: [setting: true]]\n"

      assert remove_ansi(output) == expected_content
    end

    @tag :tmp_dir
    test "handles complex nested config structures", %{tmp_dir: tmp_dir} do
      config = [
        app: [
          database: [
            hostname: "localhost",
            port: 5432,
            username: "user"
          ],
          features: [:feature_a, :feature_b]
        ]
      ]

      opts = %Options{
        approve?: nil,
        dump?: true,
        release_root: tmp_dir,
        suffix: "test",
        auto_approve?: nil
      }

      output =
        capture_io(fn ->
          result = Provider.load(config, opts)
          assert result == config
        end)

      expected_content = ~s"""
      [
        app: [
          database: [hostname: "localhost", port: 5432, username: "user"],
          features: [:feature_a, :feature_b]
        ]
      ]
      """

      assert remove_ansi(output) == expected_content
    end

    @ansi_regex ~r/\x1b\[[0-9;]*m/
    def remove_ansi(str), do: Regex.replace(@ansi_regex, str, "")
  end
end
