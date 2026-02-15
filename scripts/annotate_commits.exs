#!/usr/bin/env elixir

defmodule CommitAnnotator do
  @moduledoc """
  Annotates unpushed git commits with their corresponding chat transcript
  from TRANSCRIPT.md.
  """

  import IO.ANSI

  @commit_marker_regex ~r/Committed: `([a-f0-9]+)` at (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) — (.+)/

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

  @annotation_marker "## Chat Transcript"

  @doc """
  Builds the annotation text to append to a commit message.
  """
  def build_annotation(%{conversation: conversation}) do
    "\n\n---\n\n#{@annotation_marker}\n\n#{conversation}"
  end

  @doc """
  Returns true if a commit message has already been annotated.
  """
  def already_annotated?(message) do
    String.contains?(message, @annotation_marker)
  end

  @doc """
  Annotates unpushed commits in `repo_dir` with matching chat segments
  parsed from `transcript_content`. Uses git filter-branch to rewrite
  commit messages in a single pass.
  """
  def annotate_commits(repo_dir, transcript_content) do
    segments = parse_transcript(transcript_content)

    if segments == [] do
      IO.puts(yellow() <> "No commit markers found in transcript." <> reset())
      :ok
    else
      # Build a map of short SHA -> annotation text
      annotations = Map.new(segments, fn segment -> {segment.sha, build_annotation(segment)} end)

      # Write annotation files to a temp directory
      tmp_dir = Path.join(System.tmp_dir!(), "commit_annotator_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp_dir)

      for {sha, annotation} <- annotations do
        File.write!(Path.join(tmp_dir, sha), annotation)
      end

      # Build the msg-filter shell script
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

      # Run git filter-branch on unpushed commits
      # @{u} refers to the upstream tracking branch (e.g., origin/main)
      {output, exit_code} =
        System.cmd("git", ["filter-branch", "-f", "--msg-filter", msg_filter, "@{u}..HEAD"],
          cd: repo_dir,
          stderr_to_stdout: true,
          env: [{"FILTER_BRANCH_SQUELCH_WARNING", "1"}]
        )

      # Clean up temp files
      File.rm_rf!(tmp_dir)

      case exit_code do
        0 ->
          IO.puts(green() <> "Successfully annotated commits." <> reset())
          :ok

        _ ->
          IO.puts(red() <> "git filter-branch failed (exit #{exit_code}):" <> reset())
          IO.puts(output)
          {:error, output}
      end
    end
  end

  def run(opts) do
    file = opts[:file]
    content = File.read!(file)
    annotate_commits(".", content)
  end

  def usage do
    IO.puts("""

    #{cyan() <> bright()}Annotate Commits#{reset()} #{faint()}—#{reset()} append chat transcripts to unpushed commit messages

    #{green() <> bright()}USAGE#{reset()}
      #{cyan()}./scripts/annotate_commits.exs#{reset()} #{yellow()}--file#{reset()} TRANSCRIPT.md   #{faint()}# annotate commits#{reset()}
      #{cyan()}./scripts/annotate_commits.exs#{reset()} #{yellow()}--test#{reset()}                  #{faint()}# run self-tests#{reset()}
      #{cyan()}./scripts/annotate_commits.exs#{reset()} #{yellow()}--help#{reset()}                  #{faint()}# show this help#{reset()}

    #{green() <> bright()}OPTIONS#{reset()}
      #{yellow()}--file#{reset()} FILE   Path to the transcript markdown file #{red()}(required)#{reset()}
      #{yellow()}--test#{reset()}        Run embedded ExUnit tests
      #{yellow()}--help#{reset()}        Show this help message
    """)
  end
end

{opts, _args, _invalid} =
  OptionParser.parse(System.argv(), switches: [test: :boolean, file: :string, help: :boolean])

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
