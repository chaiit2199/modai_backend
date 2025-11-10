defmodule ModaiBackendWeb.DailyBlocController do
  use ModaiBackendWeb, :controller
  alias ModaiBackend.DailyBloc
  alias ModaiBackend.Accounts
  alias DailyGeminiAPI

  @doc """
  Lấy 3 bài viết mới nhất.
  """
  def latest_posts(conn, _params) do
    posts = DailyBloc.list_latest_posts(limit: 9)

    conn
    |> put_status(:ok)
    |> json(%{
      code: "000",
      message: "Success",
      data: Enum.map(posts, fn post ->
        %{
          title: post.title,
          search: post.search,
          category: post.category,
          image: post.image || "",
          content: post.content,
          create_date: format_date(post.published_at),
          published_ago: time_ago(post.published_at)
        }
      end)
    })
  end

  @doc """
  Lấy tất cả bài viết.
  """
  def all_posts(conn, _params) do
    posts = DailyBloc.list_posts()

    conn
    |> put_status(:ok)
    |> json(%{
      code: "000",
      message: "Success",
      data: Enum.map(posts, fn post ->
        %{
          id: post.id,
          title: post.title,
          content: post.content,
          search: post.search,
          category: post.category,
          image: post.image || "",
          create_date: format_date(post.published_at),
          published_ago: time_ago(post.published_at)
        }
      end)
    })
  end

  @doc """
  Lấy chi tiết bài viết theo search (truyền vào id là giá trị search).
  """
  def post_details(conn, params) do
    search_id = params["id"] || params[:id] || conn.path_params["id"]

    cond do
      is_nil(search_id) or search_id == "" ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          code: "001",
          message: "ID (search) is required"
        })

      true ->
        case DailyBloc.get_post_by_search(search_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{
              code: "004",
              message: "Post not found"
            })

          post ->
            conn
            |> put_status(:ok)
            |> json(%{
              code: "000",
              message: "Success",
              data: %{
                id: post.id,
                title: post.title,
                content: post.content,
                search: post.search,
                category: post.category,
                image: post.image || "",
                create_date: format_date(post.published_at),
                published_ago: time_ago(post.published_at)
              }
            })
        end
    end
  end

  @doc """
  Tạo bài viết mới (chỉ dành cho admin).
  Yêu cầu: email, username, title, và category.
  Tùy chọn: image (mặc định là chuỗi rỗng nếu không truyền).
  Sử dụng Gemini API để tạo nội dung tự động.
  """
  def create_post(conn, params) do
    email = params["email"] || params[:email]
    username = params["username"] || params[:username]
    title = params["title"] || params[:title]
    category = params["category"] || params[:category]
    image = params["image"] || params[:image] || ""

    with {:ok, _} <- validate_create_params(email, username, title, category),
         {:ok, _user} <- validate_admin_user(username, email),
         {:ok, post} <- DailyGeminiAPI.create(title, category, image) do
      conn
      |> put_status(:ok)
      |> json(%{
        code: "000",
        message: "Post created successfully",
        data: format_post_response(post)
      })
    else
      {:error, :missing_email} ->
        send_error(conn, :bad_request, "001", "Email is required")

      {:error, :missing_username} ->
        send_error(conn, :bad_request, "001", "Username is required")

      {:error, :missing_title} ->
        send_error(conn, :bad_request, "001", "Title is required")

      {:error, :missing_category} ->
        send_error(conn, :bad_request, "001", "Category is required")

      {:error, :not_admin} ->
        send_error(conn, :forbidden, "002", "Access denied. Admin role required.")

      {:error, :timeout} ->
        send_error(conn, :request_timeout, "007", "Request timeout. Please try again.")

      {:error, :not_html} ->
        send_error(conn, :unprocessable_entity, "008", "Response is not in HTML format")

      {:error, changeset} when is_struct(changeset) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          code: "003",
          message: "Failed to create post",
          errors: format_changeset_errors(changeset)
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          code: "009",
          message: "Failed to create post",
          error: inspect(reason)
        })
    end
  end

  @doc """
  Xóa bài viết theo id (chỉ dành cho admin).
  Yêu cầu: email, username, và id bài viết.
  """
  def delete_post(conn, params) do
    email = params["email"] || params[:email]
    username = params["username"] || params[:username]
    post_id = params["id"] || params[:id] || conn.path_params["id"]

    with {:ok, _} <- validate_required_params(email, username, post_id),
         {:ok, _user} <- validate_admin_user(username, email),
         {:ok, post_id_int} <- parse_post_id(post_id),
         {:ok, post} <- get_post(post_id_int),
         {:ok, deleted_post} <- DailyBloc.delete_post(post) do
      conn
      |> put_status(:ok)
      |> json(%{
        code: "000",
        message: "Post deleted successfully",
        data: format_post_response(deleted_post)
      })
    else
      {:error, :missing_email} ->
        send_error(conn, :bad_request, "001", "Email is required")

      {:error, :missing_username} ->
        send_error(conn, :bad_request, "001", "Username is required")

      {:error, :missing_post_id} ->
        send_error(conn, :bad_request, "001", "Post ID is required")

      {:error, :not_admin} ->
        send_error(conn, :forbidden, "002", "Access denied. Admin role required.")

      {:error, :invalid_post_id} ->
        send_error(conn, :bad_request, "006", "Invalid post ID")

      {:error, :post_not_found} ->
        send_error(conn, :not_found, "004", "Post not found")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          code: "003",
          message: "Failed to delete post",
          errors: format_changeset_errors(changeset)
        })
    end
  end

  @doc """
  Cập nhật bài viết (chỉ dành cho admin).
  Yêu cầu: email, username, và id bài viết.
  Có thể cập nhật: title, search, content, category, image, published_at
  """
  def update_post(conn, params) do
    email = params["email"] || params[:email]
    username = params["username"] || params[:username]
    post_id = params["id"] || params[:id] || conn.path_params["id"]

    with {:ok, _} <- validate_required_params(email, username, post_id),
         {:ok, _user} <- validate_admin_user(username, email),
         {:ok, post_id_int} <- parse_post_id(post_id),
         {:ok, post} <- get_post(post_id_int),
         {:ok, update_attrs} <- build_update_attrs(params),
         {:ok, updated_post} <- DailyBloc.update_post(post, update_attrs) do
      conn
      |> put_status(:ok)
      |> json(%{
        code: "000",
        message: "Post updated successfully",
        data: format_post_response(updated_post)
      })
    else
      {:error, :missing_email} ->
        send_error(conn, :bad_request, "001", "Email is required")

      {:error, :missing_username} ->
        send_error(conn, :bad_request, "001", "Username is required")

      {:error, :missing_post_id} ->
        send_error(conn, :bad_request, "001", "Post ID is required")

      {:error, :not_admin} ->
        send_error(conn, :forbidden, "002", "Access denied. Admin role required.")

      {:error, :invalid_post_id} ->
        send_error(conn, :bad_request, "006", "Invalid post ID")

      {:error, :post_not_found} ->
        send_error(conn, :not_found, "004", "Post not found")

      {:error, :no_fields_to_update} ->
        send_error(conn, :bad_request, "005", "No fields to update. Please provide at least one field: title, search, content, category, image, or published_at")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          code: "003",
          message: "Failed to update post",
          errors: format_changeset_errors(changeset)
        })
    end
  end

  # Validation helpers
  defp validate_create_params(email, username, title, category) do
    cond do
      is_nil(email) or email == "" -> {:error, :missing_email}
      is_nil(username) or username == "" -> {:error, :missing_username}
      is_nil(title) or title == "" -> {:error, :missing_title}
      is_nil(category) or category == "" -> {:error, :missing_category}
      true -> {:ok, :valid}
    end
  end

  defp validate_required_params(email, username, post_id) do
    cond do
      is_nil(email) or email == "" -> {:error, :missing_email}
      is_nil(username) or username == "" -> {:error, :missing_username}
      is_nil(post_id) -> {:error, :missing_post_id}
      true -> {:ok, :valid}
    end
  end

  defp validate_admin_user(username, email) do
    user = Accounts.get_user_by_username_and_email(username, email)

    if user && user.role == "admin" do
      {:ok, user}
    else
      {:error, :not_admin}
    end
  end

  defp parse_post_id(post_id) when is_integer(post_id), do: {:ok, post_id}
  defp parse_post_id(post_id) when is_binary(post_id) do
    case Integer.parse(post_id) do
      {int_id, _} -> {:ok, int_id}
      :error -> {:error, :invalid_post_id}
    end
  end
  defp parse_post_id(_), do: {:error, :invalid_post_id}

  defp get_post(post_id) do
    case DailyBloc.get_post(post_id) do
      nil -> {:error, :post_not_found}
      post -> {:ok, post}
    end
  end

  defp build_update_attrs(params) do
    update_attrs =
      %{}
      |> maybe_put(:title, params["title"] || params[:title])
      |> maybe_put(:search, params["search"] || params[:search])
      |> maybe_put(:content, params["content"] || params[:content])
      |> maybe_put(:category, params["category"] || params[:category])
      |> maybe_put(:image, params["image"] || params[:image])
      |> maybe_put_datetime(:published_at, params["published_at"] || params[:published_at])

    if map_size(update_attrs) > 0 do
      {:ok, update_attrs}
    else
      {:error, :no_fields_to_update}
    end
  end

  defp format_post_response(post) do
    %{
      id: post.id,
      title: post.title,
      search: post.search,
      content: post.content,
      category: post.category,
      image: post.image || "",
      published_at: post.published_at
    }
  end

  defp send_error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{
      code: code,
      message: message
    })
  end

  # Helper: chỉ thêm field vào map nếu giá trị không nil
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # Helper: xử lý published_at datetime
  defp maybe_put_datetime(map, _key, nil), do: map
  defp maybe_put_datetime(map, _key, ""), do: map
  defp maybe_put_datetime(map, key, published_at_str) when is_binary(published_at_str) do
    case DateTime.from_iso8601(published_at_str) do
      {:ok, datetime, _} ->
        Map.put(map, key, DateTime.truncate(datetime, :second))
      _ ->
        map
    end
  end
  defp maybe_put_datetime(map, _key, _), do: map

  # Format errors từ changeset
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # Format date từ DateTime sang string định dạng DD-MM-YYYY, HH:MM
  defp format_date(nil), do: ""
  defp format_date(datetime) do
    date = DateTime.to_date(datetime)
    day = date.day |> Integer.to_string() |> String.pad_leading(2, "0")
    month = date.month |> Integer.to_string() |> String.pad_leading(2, "0")
    year = date.year |> Integer.to_string()

    hour = datetime.hour |> Integer.to_string() |> String.pad_leading(2, "0")
    minute = datetime.minute |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{day}-#{month}-#{year}, #{hour}:#{minute}"
  end

  # Tính thời gian đã trôi qua từ published_at đến hiện tại
  defp time_ago(nil), do: ""
  defp time_ago(published_at) do
    # Tính chênh lệch trực tiếp từ UTC (chênh lệch thời gian không phụ thuộc vào timezone)
    now_utc = DateTime.utc_now()
    diff_seconds = DateTime.diff(now_utc, published_at, :second)

    cond do
      diff_seconds < 0 -> "Vừa xong"  # Nếu published_at ở tương lai (không nên xảy ra)
      diff_seconds < 60 -> "#{diff_seconds} giây trước"
      diff_seconds < 3600 ->
        minutes = div(diff_seconds, 60)
        "#{minutes} phút trước"
      diff_seconds < 86400 ->
        hours = div(diff_seconds, 3600)
        "#{hours} giờ trước"
      true ->
        days = div(diff_seconds, 86400)
        "#{days} ngày trước"
    end
  end
end
