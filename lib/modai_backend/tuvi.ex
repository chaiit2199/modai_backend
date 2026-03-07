defmodule ModaiBackend.Tuvi do
  @moduledoc """
  The Tuvi context.
  """

  import Ecto.Query, warn: false
  alias ModaiBackend.Repo
  alias ModaiBackend.Tuvi.Post

  @doc """
  Gets a single post by search.
  """
  def get_post_by_search(search), do: Repo.get_by(Post, search: search)

  @doc """
  Gets a single post by ID.
  """
  def get_post(id), do: Repo.get(Post, id)

  @doc """
  Gets all post search values for checking duplicates.
  """
  def get_post_searches do
    Post
    |> select([p], p.search)
    |> Repo.all()
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(%{field: value})
      {:ok, %Post{}}

      iex> create_post(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(attrs \\ %{}) do
    %Post{}
    |> Post.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a post.

  ## Examples

      iex> delete_post(post)
      {:ok, %Post{}}

      iex> delete_post(post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Post{} = post) do
    Repo.delete(post)
  end

  @doc """
  Lists all posts, optionally filtered by category.
  """
  def list_posts(opts \\ []) do
    query = from(p in Post)

    query =
      if category = opts[:category] do
        from p in query, where: p.category == ^category
      else
        query
      end

    # Sắp xếp theo ngày nội dung (published_at) trước, để bài viết cho "ngày mai" tạo hôm nay vẫn lên đầu khi đến mai
    query
    |> order_by([p], desc: p.published_at)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Xóa các bài viết có ngày đăng (published_at) nhỏ hơn ngày hiện tại.
  Trả về số bài đã xóa.
  """
  def delete_posts_older_than_today do
    today = Date.utc_today()
    start_of_today_utc = DateTime.new!(today, ~T[00:00:00], "Etc/UTC")

    Post
    |> where([p], p.published_at < ^start_of_today_utc)
    |> Repo.delete_all()
  end

  @doc """
  Lists latest posts with optional limit.
  Default limit is 10, can be customized via opts[:limit].
  Sorted by published_at (ngày nội dung) desc first, rồi inserted_at – để bài viết cho ngày mai tạo hôm nay vẫn hiển thị đúng thứ tự khi đến mai.
  """
  def list_latest_posts(opts \\ []) do
    limit = opts[:limit] || 10

    Post
    |> order_by([p], desc: p.published_at)
    |> order_by([p], desc: p.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
