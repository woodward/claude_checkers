#!/usr/bin/env elixir

defmodule CommitAnnotator do
  @moduledoc """
  Annotates git commits with their corresponding chat transcript.
  By default targets only unpushed commits; use `force: true` to
  include already-pushed commits.
  """

  import IO.ANSI

  @commit_marker_regex ~r/Committed: `([a-f0-9]+)` at (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) — (.+)/
  @annotation_marker "## Chat Transcript"

  # --- Public API ---

  @doc """
  Annotates commits in `repo_dir` with matching chat segments parsed from
  `transcript_content`. Uses git filter-branch to rewrite commit messages
  in a single pass.

  Options:
    - `:dry_run` — preview without modifying (default: false)
    - `:force` — include already-pushed commits (default: false)
  """
  def annotate_commits(repo_dir, transcript_content, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    force = Keyword.get(opts, :force, false)
    segments = parse_transcript(transcript_content)

    IO.puts(faint() <> "Parsed #{length(segments)} segment(s) from transcript." <> reset())

    if force do
      IO.puts(
        yellow() <>
          "Force mode: includes already-pushed commits. You will need to `git push --force` after." <> reset()
      )
    end

    if segments == [] do
      IO.puts(yellow() <> "No commit markers found in transcript." <> reset())
      :ok
    else
      annotations = Map.new(segments, fn segment -> {segment.sha, build_annotation(segment)} end)
      commits = list_commits(repo_dir, force)
      matches = Enum.filter(commits, fn {sha, _} -> Map.has_key?(annotations, sha) end)
      unmatched_count = length(commits) - length(matches)
      scope_label = if force, do: "commit(s)", else: "unpushed commit(s)"

      cond do
        matches == [] ->
          IO.puts(yellow() <> "No matching commits to annotate." <> reset())
          if dry_run, do: :dry_run, else: :ok

        dry_run ->
          IO.puts(cyan() <> bright() <> "dry run: would annotate #{length(matches)} commit(s):" <> reset())
          print_summary(matches, unmatched_count, scope_label)
          :dry_run

        true ->
          case run_filter_branch(repo_dir, annotations, force) do
            :ok ->
              IO.puts(green() <> "Annotated #{length(matches)} commit(s)." <> reset())
              print_summary(matches, unmatched_count, scope_label)
              :ok

            error ->
              error
          end
      end
    end
  end

  @doc """
  Parses a transcript string into a list of segments, each associated with a commit.

  Returns a list of maps:
    %{sha: "abc1234", timestamp: "2026-02-14 13:15:32", subject: "commit subject", conversation: "..."}
  """
  def parse_transcript(content) do
    parts = Regex.split(@commit_marker_regex, content, include_captures: true)

    parts
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn
      [conversation, marker] ->
        case Regex.run(@commit_marker_regex, marker) do
          [_, sha, timestamp, subject] ->
            [%{sha: sha, timestamp: timestamp, subject: subject, conversation: String.trim(conversation)}]

          _ ->
            []
        end

      [_trailing] ->
        []
    end)
  end

  @doc """
  Builds the annotation text to append to a commit message.
  """
  def build_annotation(%{conversation: conversation}) do
    "\n\n---\n\n#{@annotation_marker}\n\n#{conversation}"
  end

  @doc """
  Lists commits as `{sha, subject}` tuples. When `force` is true, lists
  all commits; otherwise only unpushed commits relative to the upstream.
  """
  def list_commits(repo_dir, force) do
    log_range = if force, do: "HEAD", else: "@{u}..HEAD"

    {log_output, exit_code} =
      System.cmd("git", ["log", "--format=%h %s", log_range], cd: repo_dir, stderr_to_stdout: true)

    if exit_code == 0 do
      log_output
      |> String.trim()
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        [sha | rest] = String.split(line, " ", parts: 2)
        {sha, Enum.at(rest, 0, "")}
      end)
    else
      []
    end
  end

  def run(opts) do
    file = opts[:file]
    content = File.read!(file)
    annotate_commits(".", content, dry_run: Keyword.get(opts, :dry_run, false), force: Keyword.get(opts, :force, false))
  end

  # --- Private helpers ---

  # Prints a summary of matched and unmatched commits.
  defp print_summary(matches, unmatched_count, scope_label) do
    for {sha, subject} <- matches do
      IO.puts("  #{green()}#{sha}#{reset()} — #{subject}")
    end

    if unmatched_count > 0 do
      IO.puts(faint() <> "#{unmatched_count} #{scope_label} had no matching transcript marker." <> reset())
    end
  end

  # Runs git filter-branch to rewrite commit messages, appending annotation
  # text from the given map. Returns `:ok` or `{:error, output}`.
  defp run_filter_branch(repo_dir, annotations, force) do
    tmp_dir = Path.join(System.tmp_dir!(), "commit_annotator_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    for {sha, annotation} <- annotations do
      File.write!(Path.join(tmp_dir, sha), annotation)
    end

    # GIT_COMMIT holds the original full SHA; we take the first 7 chars
    msg_filter = """
    sha=$(echo $GIT_COMMIT | cut -c1-7)
    msg=$(cat)
    annotation_file="#{tmp_dir}/$sha"
    if [ -f "$annotation_file" ]; then
      if echo "$msg" | grep -q '#{@annotation_marker}'; then
        echo "$msg"
      else
        echo "$msg"
        cat "$annotation_file"
      fi
    else
      echo "$msg"
    fi
    """

    filter_range = if force, do: "HEAD", else: "@{u}..HEAD"

    {output, exit_code} =
      System.cmd("git", ["filter-branch", "-f", "--msg-filter", msg_filter, filter_range],
        cd: repo_dir,
        stderr_to_stdout: true,
        env: [{"FILTER_BRANCH_SQUELCH_WARNING", "1"}]
      )

    File.rm_rf!(tmp_dir)

    case exit_code do
      0 -> :ok
      _ ->
        IO.puts(red() <> "git filter-branch failed (exit #{exit_code}):" <> reset())
        IO.puts(output)
        {:error, output}
    end
  end

  def usage do
    IO.puts("""

    #{cyan() <> bright()}Annotate Commits#{reset()} #{faint()}—#{reset()} append chat transcripts to commit messages

    #{green() <> bright()}USAGE#{reset()}
      #{cyan()}./scripts/annotate_commits.exs#{reset()} #{yellow()}--file#{reset()} TRANSCRIPT.md            #{faint()}# annotate unpushed commits#{reset()}
      #{cyan()}./scripts/annotate_commits.exs#{reset()} #{yellow()}--file#{reset()} TRANSCRIPT.md #{yellow()}--dry-run#{reset()}    #{faint()}# preview only#{reset()}
      #{cyan()}./scripts/annotate_commits.exs#{reset()} #{yellow()}--file#{reset()} TRANSCRIPT.md #{yellow()}--force#{reset()}      #{faint()}# include pushed commits#{reset()}
      #{cyan()}./scripts/annotate_commits.exs#{reset()} #{yellow()}--test#{reset()}                           #{faint()}# run self-tests#{reset()}
      #{cyan()}./scripts/annotate_commits.exs#{reset()} #{yellow()}--help#{reset()}                           #{faint()}# show this help#{reset()}

    #{green() <> bright()}OPTIONS#{reset()}
      #{yellow()}--file#{reset()} FILE   Path to the transcript markdown file #{red()}(required)#{reset()}
      #{yellow()}--dry-run#{reset()}     Preview which commits would be annotated without modifying them
      #{yellow()}--force#{reset()}       Include already-pushed commits (requires git push --force after)
      #{yellow()}--test#{reset()}        Run embedded ExUnit tests
      #{yellow()}--help#{reset()}        Show this help message
    """)
  end
end

# --------------------------------------------------------------------------------------------------

{opts, _args, _invalid} =
  OptionParser.parse(System.argv(),
    switches: [test: :boolean, file: :string, help: :boolean, dry_run: :boolean, force: :boolean]
  )

script_path = __ENV__.file
test_file = String.replace_trailing(script_path, ".exs", "_test.exs")

cond do
  opts[:test] ->
    if File.exists?(test_file) do
      Code.require_file(test_file)
    else
      IO.puts(IO.ANSI.red() <> "Error: test file not found at #{test_file}" <> IO.ANSI.reset())
      IO.puts("Expected sibling file: #{Path.basename(test_file)} in the same directory as this script.")
      System.halt(1)
    end

  opts[:file] ->
    CommitAnnotator.run(opts)

  true ->
    CommitAnnotator.usage()
end
