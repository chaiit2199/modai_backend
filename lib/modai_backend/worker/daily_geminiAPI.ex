defmodule DailyGeminiAPI do
  use GenServer
  import Ecto.Query
  alias ModaiBackend.Gemini.Prompt
  alias ModaiBackend.DailyBloc
  alias ModaiBackend.DailyBloc.Post
  alias ModaiBackend.Repo

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def stop() do
    GenServer.stop(__MODULE__)
  end

  # Server Callbacks
  def init(state) do
    {:ok, state}
  end

  def handle_info(:work, state) do
    # Note: create/2 now requires question and category parameters
    # Call create(question, category) directly with your question and category
    {:noreply, state}
  end

  # This function can be called by SchedEx
  def work do
    # Note: create/2 now requires question and category parameters
    # Call create(question, category) directly with your question and category
    :ok
  end

  def create(question, category, image \\ "") do
    case Prompt.call_api(question) do
      {:ok, html_content} when is_binary(html_content) ->
        # Kiểm tra xem có phải HTML không
        if String.contains?(html_content, "<") do
          title = extract_title(html_content)
          search = batch_string(title)

          case DailyBloc.create_post(%{
            title: title,
            search: search,
            category: category,
            content: html_content,
            image: image || "",
            published_at: DateTime.truncate(DateTime.utc_now(), :second)
          }) do
            {:ok, post} ->
              {:ok, post}

            {:error, changeset} ->
              IO.puts("❌ DB error khi lưu bài viết: #{inspect(changeset.errors)}")
              {:error, changeset}
          end
        else
          IO.puts("⚠️ Response không phải HTML format, bỏ qua")
          {:error, :not_html}
        end

      {:error, {:request_error, %Req.TransportError{reason: :timeout}}} ->
        IO.puts("⏱Timeout")
        {:error, :timeout}

      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp extract_title(html_content) do
    # Trích xuất tiêu đề từ thẻ <h1>
    case Regex.run(~r/<h1[^>]*>(.*?)<\/h1>/is, html_content) do
      [_, title] ->
        title
        |> String.replace(~r/<[^>]+>/, "")  # Loại bỏ các thẻ HTML bên trong
        |> String.trim()
      _ -> nil
    end
  end
  # Kiểm tra xem topic có phải là tin cũ không
  def batch_string(string) do
    (string || "")
    |> String.downcase()
    |> String.normalize(:nfd)
    |> String.replace("đ", "d")
    |> String.replace(~r/\p{Mn}/u, "")           # Bỏ dấu tiếng Việt
    |> String.replace(~r/[^a-z0-9\s-]/u, "")     # Bỏ dấu câu và ký tự đặc biệt (bao gồm dấu gạch ngang)
    |> String.replace(~r/\s+/, "-")              # Thay thế khoảng trắng bằng dấu -
    |> String.trim()                            # Loại bỏ khoảng trắng thừa cuối chuỗi
    |> String.replace(~r/^\s*cau-hoi-\d+-/, "")  # Loại bỏ "cau-hoi-X-" (cả chữ và số)
  end

  @doc """
  Xóa các bài viết cũ, chỉ giữ lại 20 bài viết mới nhất.
  Trả về số lượng bài viết đã xóa.
  """
  def keep_only_latest_posts(limit \\ 100) do
    # Lấy tất cả bài viết, sắp xếp theo inserted_at (mới nhất trước)
    all_posts = Post
      |> order_by([p], desc: p.inserted_at)
      |> Repo.all()

    # Lấy limit bài mới nhất (giữ lại)
    posts_to_keep = Enum.take(all_posts, limit)
    keep_ids = Enum.map(posts_to_keep, & &1.id)

    # Xóa các bài viết còn lại
    deleted_count = Post
      |> where([p], p.id not in ^keep_ids)
      |> Repo.delete_all()

    {:ok, deleted_count}
  end

end
