defmodule ModaiBackendWeb.AuthController do
  use ModaiBackendWeb, :controller

  alias ModaiBackend.Accounts
  alias ModaiBackendWeb.Auth.JWT

  def login(conn, %{"username" => username, "password" => password}) do
    case Accounts.authenticate_user(username, password) do
      {:ok, user} ->
        case JWT.generate_token(user) do
          {:ok, token} ->
            conn
            |> put_status(:ok)
            |> json(%{
              code: "000",
              message: "Login successful",
              token: token,
              user: %{
                id: user.id,
                username: user.username,
                email: user.email,
                role: user.role
              }
            })

          {:error, _reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{
              code: "001",
              message: "Failed to generate token"
            })
        end

      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          code: "002",
          message: "Invalid username or password"
        })
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      code: "003",
      message: "Username and password are required"
    })
  end

  def register(conn, %{"username" => _, "email" => _, "password" => _} = params) do
    # Remove role from params if present (role is set in database only)
    params = Map.drop(params, ["role"])
    case Accounts.create_user(params) do
      {:ok, _user} ->
        conn
        |> put_status(:created)
        |> json(%{
          code: "000",
          message: "Registration successful"
        })

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
            Regex.replace(~r"%{(\w+)}", message, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          code: "004",
          message: "Registration failed",
          errors: errors
        })
    end
  end

  def register(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      code: "005",
      message: "Username, email and password are required"
    })
  end

  def forgot_password(conn, %{"username" => username, "email" => email}) do
    case Accounts.generate_reset_token_by_username_and_email(username, email) do
      {:ok, user} ->
        # Send email with reset token
        email_message = ModaiBackend.Emails.UserEmail.reset_password_email(user, user.reset_token)

        case ModaiBackend.Mailer.deliver(email_message) do
          {:ok, _result} ->
            # In development, email is stored locally and can be viewed at /dev/mailbox
            conn
            |> put_status(:ok)
            |> json(%{
              code: "000",
              message: "Mã reset đã được gửi đến email",
              reset_token: user.reset_token
            })

          {:error, reason} ->
            # Log error for debugging
            require Logger
            Logger.error("Failed to send email: #{inspect(reason)}")
            Logger.error("Email details - To: #{user.email}, Token: #{user.reset_token}")

            conn
            |> put_status(:internal_server_error)
            |> json(%{
              code: "010",
              message: "Không thể gửi email. Vui lòng kiểm tra lại cấu hình SMTP.",
              error: inspect(reason),
              reset_token: user.reset_token  # Trả về token để test
            })
        end

      {:error, :not_found} ->
        # Always return success to prevent user enumeration
        conn
        |> put_status(:ok)
        |> json(%{
          code: "000",
          message: "Mã reset đã được gửi đến email"
        })
    end
  end

  def forgot_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      code: "006",
      message: "Username và email là bắt buộc"
    })
  end

  def reset_password(conn, %{"reset_token" => reset_token, "password" => password}) do
    case Accounts.reset_password(reset_token, password) do
      {:ok, user} ->
        conn
        |> put_status(:ok)
        |> json(%{
          code: "000",
          message: "Password reset successful",
          user: %{
            id: user.id,
            username: user.username,
            email: user.email,
            role: user.role
          }
        })

      {:error, :invalid_token} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          code: "007",
          message: "Invalid or expired reset token"
        })

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
            Regex.replace(~r"%{(\w+)}", message, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          code: "008",
          message: "Password reset failed",
          errors: errors
        })
    end
  end

  def reset_password(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      code: "009",
      message: "Reset token and password are required"
    })
  end
end
