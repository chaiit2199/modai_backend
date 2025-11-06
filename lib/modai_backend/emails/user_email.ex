defmodule ModaiBackend.Emails.UserEmail do
  import Swoosh.Email

  def reset_password_email(user, reset_token) do
    new()
    |> to({user.username, user.email})
    |> from({"Modai Backend", "noreply@modai.com"})
    |> subject("Reset Password - Modai Backend")
    |> html_body("""
    <html>
      <body>
        Xin chào strong>#{user.username}</strong>, Bấm vào link sau để đặt lại mật khẩu:
        <a style="color: blue; text-decoration: underline; font-weight: bold;" href="http://localhost:3000/auth/reset-password?token=#{reset_token}">Reset password</a>
        Mã reset sẽ hết hạn sau 1 giờ.
        Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.
      </body>
    </html>
    """)
    |> text_body("""
    Reset Password Request

    Xin chào strong>#{user.username}</strong>, Bấm vào link sau để đặt lại mật khẩu:
    <a style="color: blue; text-decoration: underline; font-weight: bold;" href="http://localhost:3000/auth/reset-password?token=#{reset_token}">Reset password</a>
    Mã reset sẽ hết hạn sau 1 giờ.
    Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.
    """)
  end
end
