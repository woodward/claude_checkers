ExUnit.start()

defmodule CommitAnnotatorTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  # Helper to run git commands in a specific directory
  defp git(repo_dir, args) do
    {output, 0} = System.cmd("git", args, cd: repo_dir, stderr_to_stdout: true)
    String.trim(output)
  end

  # Sets up a git repo with a bare remote and one pushed commit,
  # returns %{work_dir: ..., bare_dir: ...}
  defp setup_repo(tmp_dir) do
    bare_dir = Path.join(tmp_dir, "remote.git")
    work_dir = Path.join(tmp_dir, "repo")

    System.cmd("git", ["init", "--bare", bare_dir])
    System.cmd("git", ["clone", bare_dir, work_dir], stderr_to_stdout: true)
    git(work_dir, ["config", "user.email", "test@test.com"])
    git(work_dir, ["config", "user.name", "Test User"])

    # Initial commit + push so we have origin/main
    File.write!(Path.join(work_dir, "README.md"), "# Test")
    git(work_dir, ["add", "."])
    git(work_dir, ["commit", "-m", "Initial commit"])
    git(work_dir, ["push", "-u", "origin", "HEAD"])

    %{work_dir: work_dir, bare_dir: bare_dir}
  end

  # Gets the short SHA and formatted timestamp for a commit
  defp commit_info(work_dir, skip \\ 0) do
    sha = git(work_dir, ["log", "--format=%h", "-1", "--skip=#{skip}"])
    raw_ts = git(work_dir, ["log", "--format=%ci", "-1", "--skip=#{skip}"])
    # %ci gives "2026-02-14 16:53:02 -0800", we want just "2026-02-14 16:53:02"
    timestamp = String.slice(raw_ts, 0, 19)
    {sha, timestamp}
  end

  describe "parse_transcript/1" do
    test "extracts a single commit segment" do
      transcript = """
      **User**

      Can you alphabetize the dependencies in mix.exs?

      ---

      **Cursor**

      Done — dependencies are now alphabetized.

      Committed: `56fc54c` at 2026-02-14 13:15:32 — Alphabetize mix.exs dependencies
      """

      segments = CommitAnnotator.parse_transcript(transcript)

      assert length(segments) == 1
      [segment] = segments
      assert segment.sha == "56fc54c"
      assert segment.timestamp == "2026-02-14 13:15:32"
      assert segment.subject == "Alphabetize mix.exs dependencies"
      assert segment.conversation =~ "Can you alphabetize the dependencies"
      assert segment.conversation =~ "Done — dependencies are now alphabetized."
    end

    test "extracts multiple commit segments in order" do
      transcript = """
      **User**

      Can you alphabetize the dependencies?

      ---

      **Cursor**

      Done — alphabetized.

      Committed: `aaa1111` at 2026-02-14 13:00:00 — Alphabetize dependencies

      ---

      **User**

      Now update the versions please.

      ---

      **Cursor**

      Updated all versions.

      Committed: `bbb2222` at 2026-02-14 13:10:00 — Update dependency versions

      ---

      **User**

      Thanks, looks great!
      """

      segments = CommitAnnotator.parse_transcript(transcript)

      assert length(segments) == 2

      [first, second] = segments

      assert first.sha == "aaa1111"
      assert first.subject == "Alphabetize dependencies"
      assert first.conversation =~ "Can you alphabetize the dependencies"
      assert first.conversation =~ "Done — alphabetized."

      assert second.sha == "bbb2222"
      assert second.subject == "Update dependency versions"
      assert second.conversation =~ "Now update the versions"
      assert second.conversation =~ "Updated all versions."
    end

    test "returns empty list when no commits found" do
      transcript = """
      **User**

      Just chatting, no commits here.

      ---

      **Cursor**

      Sure, let's just talk!
      """

      assert CommitAnnotator.parse_transcript(transcript) == []
    end
  end

  describe "build_annotation/1" do
    test "formats a segment as a commit message annotation" do
      segment = %{
        sha: "abc1234",
        timestamp: "2026-02-14 13:15:32",
        subject: "Alphabetize dependencies",
        conversation: "**User**\n\nCan you alphabetize?\n\n---\n\n**Cursor**\n\nDone!"
      }

      annotation = CommitAnnotator.build_annotation(segment)

      assert annotation =~ "---"
      assert annotation =~ "## Chat Transcript"
      assert annotation =~ "Can you alphabetize?"
      assert annotation =~ "Done!"
      # Should start with blank line + hr + blank line + heading
      assert String.starts_with?(annotation, "\n\n---\n\n## Chat Transcript\n\n")
    end

    test "idempotency check detects already-annotated message" do
      original = "Fix a bug\n\n---\n\n## Chat Transcript\n\nSome chat here"

      assert CommitAnnotator.already_annotated?(original)
      refute CommitAnnotator.already_annotated?("Fix a bug\n\nJust a normal message body")
    end
  end

  describe "annotate_commits/2 integration" do
    @tag :tmp_dir
    test "annotates unpushed commits with matching transcript chat", %{tmp_dir: tmp_dir} do
      %{work_dir: work_dir} = setup_repo(tmp_dir)

      # Make two unpushed commits
      File.write!(Path.join(work_dir, "file1.txt"), "hello")
      git(work_dir, ["add", "."])
      git(work_dir, ["commit", "-m", "Add file1"])

      File.write!(Path.join(work_dir, "file2.txt"), "world")
      git(work_dir, ["add", "."])
      git(work_dir, ["commit", "-m", "Add file2"])

      # Get their SHAs and timestamps (skip=1 is the older one)
      {sha1, ts1} = commit_info(work_dir, 1)
      {sha2, ts2} = commit_info(work_dir, 0)

      # Build a transcript referencing both commits
      transcript = """
      **User**

      Please add file1

      ---

      **Cursor**

      Added file1.

      Committed: `#{sha1}` at #{ts1} — Add file1

      ---

      **User**

      Now add file2

      ---

      **Cursor**

      Added file2.

      Committed: `#{sha2}` at #{ts2} — Add file2
      """

      # Run the annotator
      capture_io(fn -> CommitAnnotator.annotate_commits(work_dir, transcript) end)

      # Verify both commit messages were annotated
      msg1 = git(work_dir, ["log", "--format=%B", "-1", "--skip=1"])
      msg2 = git(work_dir, ["log", "--format=%B", "-1"])

      assert msg1 =~ "Add file1"
      assert msg1 =~ "## Chat Transcript"
      assert msg1 =~ "Please add file1"

      assert msg2 =~ "Add file2"
      assert msg2 =~ "## Chat Transcript"
      assert msg2 =~ "Now add file2"
    end

    @tag :tmp_dir
    test "is idempotent — running twice does not double-annotate", %{tmp_dir: tmp_dir} do
      %{work_dir: work_dir} = setup_repo(tmp_dir)

      # Make one unpushed commit
      File.write!(Path.join(work_dir, "file1.txt"), "hello")
      git(work_dir, ["add", "."])
      git(work_dir, ["commit", "-m", "Add file1"])

      {sha, ts} = commit_info(work_dir)

      transcript = """
      **User**

      Please add file1

      ---

      **Cursor**

      Added file1.

      Committed: `#{sha}` at #{ts} — Add file1
      """

      # Run twice
      capture_io(fn -> CommitAnnotator.annotate_commits(work_dir, transcript) end)
      capture_io(fn -> CommitAnnotator.annotate_commits(work_dir, transcript) end)

      # Should only have one "## Chat Transcript" marker
      msg = git(work_dir, ["log", "--format=%B", "-1"])
      occurrences = msg |> String.split("## Chat Transcript") |> length()
      # If split produces 2 parts, there's exactly 1 occurrence
      assert occurrences == 2, "Expected exactly 1 annotation marker, got #{occurrences - 1}"
    end
  end
end
