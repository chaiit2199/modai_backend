defmodule ModaiBackendWeb.TuviController do
  use ModaiBackendWeb, :controller
  alias ModaiBackend.Tuvi
  alias ModaiBackend.Accounts
  alias DailyGeminiAPI

  @doc """
  Lấy 9 bài viết mới nhất. Trước khi trả về, xóa các bài có ngày đăng (published_at) nhỏ hơn ngày hiện tại.
  """
  def latest_posts(conn, _params) do
    _deleted_count = Tuvi.delete_posts_older_than_today()
    posts = Tuvi.list_latest_posts(limit: 9)

    conn
    |> put_status(:ok)
    |> json(%{
      code: "000",
      message: "Success",
      data:
        Enum.map(posts, fn post ->
          %{
            title: post.title,
            search: post.search,
            category: post.category,
            image: post.image || "",
            content: post.content,
            create_date: format_date(post.published_at),
            published_ago: time_ago(post.inserted_at)
          }
        end)
    })
  end

  @doc """
  Lấy tất cả bài viết.
  """
  def all_posts(conn, _params) do
    posts = Tuvi.list_posts()

    conn
    |> put_status(:ok)
    |> json(%{
      code: "000",
      message: "Success",
      data:
        Enum.map(posts, fn post ->
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
        case Tuvi.get_post_by_search(search_id) do
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
  Yêu cầu: email, username, category, và prompt (block ngày: dương lịch, âm lịch, ngày hoàng đạo, sao, trực, giờ hoàng đạo, màu/số may mắn).
  Tùy chọn: title (dùng khi không có prompt), image (mặc định chuỗi rỗng).
  Sử dụng Gemini API để tạo nội dung tử vi tự động.
  """
  def create_post(conn, params) do
    email = params["email"] || params[:email]
    username = params["username"] || params[:username]
    title = params["title"] || params[:title]
    category = params["category"] || params[:category]
    prompt = params["prompt"] || params[:prompt]
    image = params["image"] || params[:image] || ""

    with {:ok, _} <- validate_create_params_tuvi(email, username, category, prompt, title),
         {:ok, _user} <- validate_admin_user(username, email),
         {:ok, post} <- DailyGeminiAPI.create_tuvi(prompt || title, category, image) do
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

      {:error, :missing_prompt_or_title} ->
        send_error(conn, :bad_request, "001", "Prompt (block ngày) hoặc title is required")

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

      {:error, :missing_api_key} ->
        send_error(conn, :service_unavailable, "009", "Gemini API key is not configured")

      {:error, :missing_url} ->
        send_error(conn, :service_unavailable, "009", "Gemini URL is not configured")

      {:error, {:api_error, 403, %{"error" => %{"message" => msg}}}} ->
        send_error(conn, :forbidden, "009", "Gemini API: #{msg}")

      {:error, {:api_error, _status, body}} ->
        message = extract_gemini_error_message(body)
        conn
        |> put_status(:internal_server_error)
        |> json(%{code: "009", message: "Gemini API error", error: message})

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
  Xóa bài viết theo id hoặc slug (search) – chỉ dành cho admin.
  Yêu cầu: email, username, và id/slug bài viết.
  """
  def delete_post(conn, params) do
    email = params["email"] || params[:email]
    username = params["username"] || params[:username]
    post_id = params["id"] || params[:id] || conn.path_params["id"]

    with {:ok, _} <- validate_required_params(email, username, post_id),
         {:ok, _user} <- validate_admin_user(username, email) do
      do_delete_post(conn, post_id)
    else
      {:error, :missing_email} ->
        send_error(conn, :bad_request, "001", "Email is required")

      {:error, :missing_username} ->
        send_error(conn, :bad_request, "001", "Username is required")

      {:error, :missing_post_id} ->
        send_error(conn, :bad_request, "001", "Post ID is required")

      {:error, :not_admin} ->
        send_error(conn, :forbidden, "002", "Access denied. Admin role required.")
    end
  end

  defp do_delete_post(conn, post_id) do
    post =
      case parse_post_id(post_id) do
        {:ok, post_id_int} -> Tuvi.get_post(post_id_int)
        {:error, :invalid_post_id} -> Tuvi.get_post_by_search(post_id)
      end

    case post do
      nil ->
        send_error(conn, :not_found, "004", "Post not found")

      post ->
        case Tuvi.delete_post(post) do
          {:ok, deleted_post} ->
            conn
            |> put_status(:ok)
            |> json(%{
              code: "000",
              message: "Post deleted successfully",
              data: format_post_response(deleted_post)
            })

          {:error, _changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              code: "003",
              message: "Failed to delete post"
            })
        end
    end
  end

  @doc """
  Cập nhật bài viết theo id hoặc slug (search) – chỉ dành cho admin.
  Yêu cầu: email, username, id/slug bài viết. Có thể cập nhật: title, search, content, category, image, published_at
  """
  def update_post(conn, params) do
    email = params["email"] || params[:email]
    username = params["username"] || params[:username]
    post_id = params["id"] || params[:id] || conn.path_params["id"]

    with {:ok, _} <- validate_required_params(email, username, post_id),
         {:ok, _user} <- validate_admin_user(username, email),
         {:ok, post} <- get_post_by_id_or_search(post_id),
         {:ok, update_attrs} <- build_update_attrs(params),
         {:ok, updated_post} <- Tuvi.update_post(post, update_attrs) do
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

      {:error, :post_not_found} ->
        send_error(conn, :not_found, "004", "Post not found")

      {:error, :no_fields_to_update} ->
        send_error(
          conn,
          :bad_request,
          "005",
          "No fields to update. Please provide at least one field: title, search, content, category, image, or published_at"
        )

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
  defp validate_create_params_tuvi(email, username, category, prompt, title) do
    cond do
      is_nil(email) or email == "" -> {:error, :missing_email}
      is_nil(username) or username == "" -> {:error, :missing_username}
      is_nil(category) or category == "" -> {:error, :missing_category}
      (is_nil(prompt) or prompt == "") and (is_nil(title) or title == "") ->
        {:error, :missing_prompt_or_title}
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

  defp get_post_by_id_or_search(post_id) do
    post =
      case parse_post_id(post_id) do
        {:ok, post_id_int} -> Tuvi.get_post(post_id_int)
        {:error, :invalid_post_id} -> Tuvi.get_post_by_search(post_id)
      end

    case post do
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

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

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

  defp extract_gemini_error_message(%{"error" => %{"message" => msg}}) when is_binary(msg), do: msg
  defp extract_gemini_error_message(body), do: inspect(body)

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

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

  defp time_ago(nil), do: ""

  defp time_ago(published_at) do
    now_utc = DateTime.utc_now()
    diff_seconds = DateTime.diff(now_utc, published_at, :second)

    cond do
      diff_seconds < 0 ->
        "Vừa xong"

      diff_seconds < 60 ->
        "#{diff_seconds} giây trước"

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
