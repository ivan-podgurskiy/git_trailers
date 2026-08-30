defmodule GitTrailers.Differential do
  @moduledoc false

  alias GitTrailers.Conformance

  @required_version "git version 2.54.0"

  @spec run!() :: :ok
  def run! do
    git = System.get_env("GIT_TRAILERS_GIT") || raise "GIT_TRAILERS_GIT is required"
    verify_version!(git)

    root =
      Path.join(
        System.tmp_dir!(),
        "git-trailers-differential-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)

    try do
      corpus = Conformance.load!()
      parse_cases = corpus["parseCases"] ++ supplemental_parse_cases()
      add_cases = corpus["addCases"] ++ supplemental_add_cases()
      failures = parse_failures(parse_cases, git, root)
      failures = failures ++ add_failures(add_cases, git, root)

      if failures != [] do
        raise Enum.join(failures, "\n\n")
      end

      IO.puts(
        "Git 2.54.0 differential checks passed " <>
          "(#{length(parse_cases)} parse, #{length(add_cases)} add)"
      )
    after
      File.rm_rf!(root)
    end

    :ok
  end

  defp verify_version!(git) do
    case System.cmd(git, ["--version"], stderr_to_stdout: true) do
      {@required_version <> "\n", 0} ->
        :ok

      {output, status} ->
        raise "expected #{@required_version}; status #{status}, output #{inspect(output)}"
    end
  end

  defp parse_failures(cases, git, root) do
    Enum.flat_map(cases, fn test_case ->
      options = test_case["options"] || %{}
      {:ok, result} = GitTrailers.parse(test_case["input"], Conformance.parse_options(options))
      expected = expected_parse_output(result, options)

      args = git_config_args(options) ++ ["interpret-trailers", parse_mode(options)]
      args = if options["unfold"] == false, do: args ++ ["--only-input"], else: args
      args = if options["divider"] == false, do: args ++ ["--no-divider"], else: args

      compare(git, args, test_case["input"], expected, "parse: #{test_case["name"]}", root)
    end)
  end

  defp add_failures(cases, git, root) do
    Enum.flat_map(cases, fn test_case ->
      options = test_case["options"] || %{}
      trailers = Enum.map(test_case["trailers"], &{&1["key"], &1["value"]})
      expected = GitTrailers.add(test_case["input"], trailers, Conformance.add_options(options))

      args = git_config_args(options) ++ ["interpret-trailers"]
      args = add_option_args(args, options)
      args = args ++ Enum.map(test_case["trailers"], &"--trailer=#{&1["key"]}=#{&1["value"]}")

      compare(git, args, test_case["input"], expected, "add: #{test_case["name"]}", root)
    end)
  end

  defp expected_parse_output(result, options) do
    separator = options |> Map.get("separators", ":") |> String.first()
    known_keys = Map.get(options, "knownKeys", [])

    Enum.map_join(result.trailers, fn trailer ->
      key =
        Enum.find(known_keys, trailer.key, fn known ->
          String.downcase(known) == String.downcase(trailer.key)
        end)

      "#{key}#{separator} #{trailer.value}\n"
    end)
  end

  defp git_config_args(options) do
    separator_args =
      case options do
        %{"separators" => separators} -> ["-c", "trailer.separators=#{separators}"]
        _options -> []
      end

    known_args =
      options
      |> Map.get("knownKeys", [])
      |> Enum.with_index()
      |> Enum.flat_map(fn {key, index} -> ["-c", "trailer.conformance#{index}.key=#{key}"] end)

    separator_args ++ known_args
  end

  defp parse_mode(%{"unfold" => false}), do: "--only-trailers"
  defp parse_mode(_options), do: "--parse"

  defp add_option_args(args, options) do
    mappings = [
      {"where", "--where"},
      {"ifExists", "--if-exists"},
      {"ifMissing", "--if-missing"}
    ]

    args =
      Enum.reduce(mappings, args, fn {key, flag}, current ->
        case options do
          %{^key => value} -> current ++ ["#{flag}=#{value}"]
          _options -> current
        end
      end)

    args = if options["trimEmpty"] == true, do: args ++ ["--trim-empty"], else: args
    if options["divider"] == false, do: args ++ ["--no-divider"], else: args
  end

  defp supplemental_parse_cases do
    [
      %{
        "name" => "comment accounts for a pending orphan continuation",
        "input" => "subject\n\nKey: one\n# note\n  orphan\nOther: two\n"
      },
      %{
        "name" => "unfold retains whitespace before the physical newline",
        "input" => "subject\n\nKey: one   \n  two\n"
      },
      %{
        "name" => "unfold retains CR before a folded CRLF newline",
        "input" => "subject\r\n\r\nKey: one   \r\n  two\r\n"
      }
    ]
  end

  defp supplemental_add_cases do
    [
      %{
        "name" => "folded existing value differs from unfolded input",
        "input" => "subject\n\nKey: one\n  two\n",
        "trailers" => [%{"key" => "Key", "value" => "one two"}]
      },
      %{
        "name" => "mutation preserves whitespace before a folded newline",
        "input" => "subject\n\nKey: one   \n  two\n",
        "trailers" => [%{"key" => "Other", "value" => "x"}]
      },
      %{
        "name" => "mutation trims the folded value's trailing boundary",
        "input" => "subject\n\nKey: one\n  two   \n",
        "trailers" => [%{"key" => "Other", "value" => "x"}]
      },
      %{
        "name" => "mutation trims the folded value's leading boundary",
        "input" => "subject\n\nKey:    \n  two\n",
        "trailers" => [%{"key" => "Other", "value" => "x"}]
      },
      %{
        "name" => "trim empty mutates without incoming trailers",
        "input" => "subject\n\nFixes:   \nReviewed-by: A\n",
        "trailers" => [],
        "options" => %{"trimEmpty" => true}
      }
    ]
  end

  defp compare(git, args, input, expected, name, root) do
    path = Path.join(root, "case-#{System.unique_integer([:positive])}.txt")
    File.write!(path, input)

    case System.cmd(git, args ++ [path], cd: root, stderr_to_stdout: true) do
      {^expected, 0} ->
        []

      {output, 0} ->
        ["#{name}: byte mismatch\nexpected #{inspect(expected)}\nreceived #{inspect(output)}"]

      {output, status} ->
        ["#{name}: Git exited #{status}: #{inspect(output)}"]
    end
  end
end

GitTrailers.Differential.run!()
