defmodule ModaiBackend.Gemini.Prompt do
  require Logger

  def call_api(prompt) do

    prompt_with_format = """
      YÊU CẦU VỀ SEO:
      - Tiêu đề <h1> phải chứa từ khóa chính, hấp dẫn, dài 50-60 ký tự
      - Sử dụng từ khóa tự nhiên trong nội dung, không nhồi nhét
      - Mỗi đoạn <p> nên có 2-4 câu, dễ đọc
      - Sử dụng <h2>, <h3> để chia nhỏ nội dung, mỗi heading chứa từ khóa liên quan
      - Nội dung phải có giá trị, thông tin chính xác và cập nhật

      Yêu cầu về nội dung:
      - Bài viết phải mang tính thời sự, cập nhật và chính xác
      - Tập trung vào các sự kiện bóng đá: trận đấu, chuyển nhượng, tin tức câu lạc bộ, giải đấu, cầu thủ
      - Sử dụng ngôn ngữ chuyên nghiệp, dễ hiểu, phù hợp với độc giả yêu thích bóng đá
      - Bao gồm các thông tin quan trọng: đội bóng, cầu thủ, thời gian, địa điểm (nếu có)
      - Độ dài bài viết: 400-600 từ, đảm bảo đầy đủ thông tin

      CẤU TRÚC HTML (QUAN TRỌNG):
      - TẤT CẢ nội dung văn bản phải được bọc trong thẻ <p>
      - KHÔNG sử dụng <div> cho nội dung văn bản
      - Chỉ dùng <div> cho phần kết luận (nếu cần)

      Cấu trúc bài viết:
      1. Tiêu đề: <h1>Tiêu đề bài viết (50-60 ký tự, chứa từ khóa)</h1>
      2. Đoạn mở đầu: <p class="lead">Tóm tắt sự kiện (2-3 câu, chứa từ khóa chính)</p>
      3. Nội dung chính:
        - <h2>Tiêu đề phần 1</h2>
        - <p>Nội dung đoạn 1...</p>
        - <p>Nội dung đoạn 2...</p>
        - <h3>Tiêu đề phụ</h3>
        - <p>Nội dung chi tiết...</p>
      4. Kết luận: <div>Kết luận về ý nghĩa sự kiện...</div>

      Yêu cầu về HTML:
      - TẤT CẢ nội dung văn bản phải trong thẻ <p>
      - Sử dụng <strong> cho tên đội bóng, cầu thủ, số liệu quan trọng
      - Sử dụng <em> cho nhấn mạnh thông tin
      - Sử dụng <h2>, <h3> để chia nhỏ nội dung (tối đa 3-4 heading)
      - Phần kết luận dùng <div> thay vì <p>
      - Không sử dụng thẻ <html>, <head>, <body>, <article>, <section>
      - Đảm bảo HTML hợp lệ và có thể hiển thị trực tiếp

      Ví dụ cấu trúc HTML:
      <h1>Tiêu đề bài viết chứa từ khóa chính</h1>
      <p class="lead">Đoạn mở đầu tóm tắt sự kiện, chứa từ khóa...</p>
      <h2>Tiêu đề phần nội dung</h2>
      <p>Nội dung chi tiết đoạn 1...</p>
      <p><strong>Tên đội bóng</strong> đã thực hiện...</p>
      <p>Nội dung chi tiết đoạn 2...</p>
      <h3>Tiêu đề phụ</h3>
      <p>Nội dung bổ sung...</p>
      <div>Kết luận về ý nghĩa sự kiện...</div>

      Chủ đề/chủ đề cần viết:
      #{prompt}

      Hãy viết bài tin tức bóng đá theo yêu cầu trên và trả về kết quả dưới dạng HTML (chỉ nội dung bài viết, không có thẻ html/head/body).
    """
    api_key = Application.get_env(:modai_backend, :API_KEY_GEMINI)
    url_gemini = Application.get_env(:modai_backend, :URL_GEMINI)

    # Validate config values
    cond do
      is_nil(api_key) or api_key == "" ->
        Logger.error("API_KEY_GEMINI is not configured")
        {:error, :missing_api_key}

      is_nil(url_gemini) or url_gemini == "" ->
        Logger.error("URL_GEMINI is not configured")
        {:error, :missing_url}

      true ->
        # Ensure URL has scheme
        url = if String.starts_with?(url_gemini, "http://") or String.starts_with?(url_gemini, "https://") do
          "#{url_gemini}#{api_key}"
        else
          "https://#{url_gemini}#{api_key}"
        end

        request_body = %{
          "contents" => [
            %{
              "parts" => [
                %{
                  "text" => prompt_with_format
                }
              ]
            }
          ]
        }

        # Tăng timeout lên 90 giây vì Gemini có thể mất thời gian để tạo nội dung dài
        case Req.post(url, json: request_body, receive_timeout: 90_000) do
          {:ok, %Req.Response{status: 200, body: response_body}} ->
            case response_body do
              %{"candidates" => [%{"content" => %{"parts" => [%{"text" => response_text} | _]}}]} ->
                {:ok, parse_response_text(response_text)}  # Gọi hàm parse_response_text

              _decoded_response ->
                Logger.error("Unexpected JSON structure: #{inspect(response_body)}")
                {:error, :unexpected_structure}
            end

          {:ok, %Req.Response{status: status_code, body: error_body}} ->
            Logger.error("API: #{status_code} - #{inspect(error_body)}")
            {:error, {:api_error, status_code, error_body}}

          {:error, %Jason.DecodeError{} = error} ->
            Logger.error("Response body is not valid JSON: #{inspect(error)}")
            {:error, :invalid_json}

          {:error, error} ->
            Logger.error("Request error: #{inspect(error)}")
            {:error, {:request_error, error}}
        end
    end
  end

  # Định nghĩa hàm parse_response_text để xử lý chuỗi response_text trả về (HTML)
  defp parse_response_text(response_text) do
    # Loại bỏ markdown code blocks nếu có (```html hoặc ```)
    cleaned_text = response_text
      |> String.replace("```html", "")
      |> String.replace("```", "")
      |> String.trim()

    # Làm sạch HTML: loại bỏ các dòng trống thừa nhưng giữ nguyên cấu trúc
    cleaned_text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(fn line ->
      # Giữ lại các dòng có nội dung (không phải dòng trống hoàn toàn)
      line != ""
    end)
    |> Enum.join("\n")
    |> String.replace(~r/\n{3,}/, "\n\n")  # Thay thế nhiều dòng trống liên tiếp bằng 2 dòng trống
    |> String.trim()
  end

end
