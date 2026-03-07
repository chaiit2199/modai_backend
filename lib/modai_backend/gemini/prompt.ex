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

    do_call_api(prompt_with_format)
  end

  @doc """
  Gọi Gemini API để tạo nội dung bài viết tử vi.
  - prompt: nếu bắt đầu bằng "Prompt1" → dùng template "Nên làm gì"; "Prompt2" → "Không nên làm gì / Kiêng kỵ".
    Phần còn lại sau prefix là block thông tin ngày (dương lịch, âm lịch, ngày hoàng đạo...).
  - category: thể loại bài (vd: tu-vi-ngay...).
  Trả về HTML phù hợp cho mục Tuvi.
  """
  def call_api_tuvi(prompt, category \\ nil) do
    prompt = String.trim(prompt)
    {content_instructions, date_block} = parse_tuvi_prompt_prefix(prompt)

    category_instruction =
      if category && category != "" do
        "Thể loại/chuyên mục bài viết: #{category}. Nội dung phải phù hợp với thể loại này.\n"
      else
        ""
      end

    prompt_with_format = """
      YÊU CẦU VỀ SEO VÀ TIÊU ĐỀ (RẤT QUAN TRỌNG):
      - Tiêu đề <h1> phải GIẬT GÂN, GÂY SỰ CHÚ Ý, khiến người đọc muốn bấm vào ngay (kiểu headline thu hút, gợi tò mò, tạo cảm giác khẩn cấp hoặc lợi ích rõ ràng)
      - Dài 55-75 ký tự, dùng từ mạnh, cụ thể, tránh tiêu đề chung chung nhàm chán
      - Bắt buộc kết thúc tiêu đề bằng ngày dương lịch trong ngoặc: (DD/MM/YYYY) – lấy từ thông tin ngày bên dưới
      - Sử dụng từ khóa tự nhiên trong nội dung (tử vi, kiêng kỵ, nên làm...)
      - Mỗi đoạn <p> nên có 2-4 câu, dễ đọc
      - Sử dụng <h2>, <h3> để chia nhỏ nội dung
      #{category_instruction}

      #{content_instructions}

      CẤU TRÚC HTML (QUAN TRỌNG):
      - TẤT CẢ nội dung văn bản phải được bọc trong thẻ <p>
      - Chỉ dùng <div> cho phần kết luận (nếu cần)

      Cấu trúc bài viết:
      1. Tiêu đề: <h1>Tiêu đề theo đúng format được mô tả trong từng loại bài (Nên làm / Kiêng kỵ) bên dưới, kết thúc bằng (DD/MM/YYYY)</h1>
      2. Đoạn mở đầu: <p class="lead">Tóm tắt...</p>
      3. Nội dung chính: <h2>, <h3>, <p>...
      4. Kết luận: <div>Lời khuyên hoặc kết luận...</div>

      Yêu cầu về HTML:
      - TẤT CẢ nội dung văn bản phải trong thẻ <p>
      - Sử dụng <strong> cho từ khóa quan trọng, <em> cho nhấn mạnh
      - Không sử dụng thẻ <html>, <head>, <body>, <article>, <section>
      - Chỉ trả về nội dung bài viết HTML, không có thẻ html/head/body

      Thông tin ngày (dương lịch, âm lịch, ngày hoàng đạo, sao, trực, giờ hoàng đạo, màu/số may mắn...) – dùng làm ngữ cảnh chính để viết bài:
      #{date_block}

      Hãy viết bài tử vi dựa trên thông tin ngày trên và trả về kết quả dưới dạng HTML (chỉ nội dung bài viết).
    """

    do_call_api(prompt_with_format)
  end

  # Nếu prompt bắt đầu bằng "Prompt1" hoặc "Prompt2" thì tách prefix và trả về {content_instructions, date_block}.
  defp parse_tuvi_prompt_prefix(prompt) do
    cond do
      String.starts_with?(prompt, "Prompt1") ->
        date_block = prompt |> String.replace_prefix("Prompt1", "") |> String.trim()
        {tuvi_prompt1_content(), date_block}

      String.starts_with?(prompt, "Prompt2") ->
        date_block = prompt |> String.replace_prefix("Prompt2", "") |> String.trim()
        {tuvi_prompt2_content(), date_block}

      true ->
        # Mặc định dùng Prompt1 (Nên làm gì)
        {tuvi_prompt1_content(), prompt}
    end
  end

  defp tuvi_prompt1_content do
    """
    YÊU CẦU NỘI DUNG (RẤT QUAN TRỌNG):

    - Đây là bài viết CHỈ tập trung vào: NHỮNG VIỆC NÊN LÀM TRONG NGÀY.
    - Không viết lan sang tình duyên, cung hoàng đạo, vận mệnh dài dòng.
    - Không phân tích chung chung về tử vi năm.
    - Không viết nội dung kiểu dự đoán số phận.
    - Nội dung phải xoay quanh: hành động cụ thể nên thực hiện trong ngày.

    FORMAT TIÊU ĐỀ (NGÀY TỐT – GIẬT GÂN, THU HÚT):
    - Tiêu đề phải tạo cảm giác "đừng bỏ lỡ", "cơ hội vàng", lợi ích cụ thể (tài lộc, thành công, hanh thông).
    - Cấu trúc gợi ý: "Ngày Đại Cát: [Việc nên làm + lợi ích hấp dẫn] – [Kết quả mong đợi/Lời chúc mạnh] (DD/MM/YYYY)"
    - Ví dụ giật gân: "Ngày Đại Cát: Khai Trương Hôm Nay – Tài Lộc Ùn Ùn, Làm Ăn Phát Đạt (04/03/2026)"
    - Ví dụ: "Ngày Vàng Cưới Hỏi: Hạnh Phúc Trọn Đời – Đừng Bỏ Lỡ Ngày Tốt Hiếm Có (05/03/2026)"
    - Ví dụ: "Tử Vi 06/03: Ngày Cực Tốt Động Thổ, Ký Hợp Đồng – Lợi Lộc Bền Vững (06/03/2026)"
    - DD/MM/YYYY lấy từ ngày dương lịch trong block thông tin ngày. Tiêu đề phải kết thúc bằng (ngày).

    Bắt buộc nội dung:
    - Tập trung giải thích vì sao ngày này thuận lợi (Hoàng đạo, sao tốt, trực tốt…)
    - Phân tích rõ từng việc nên làm: cưới hỏi, ký kết, khai trương, sửa nhà, cầu tài…
    - Giải thích dựa trên: Ngày hoàng đạo/hắc đạo, Sao ngày, Trực ngày, Sao tốt – sao xấu
    - Viết theo hướng khuyến nghị tích cực, rõ ràng, cụ thể

    Tuyệt đối không viết nội dung kiểu:
    - "Hôm nay vận tình duyên khởi sắc…"
    - "Bạn sẽ gặp may mắn trong chuyện tình cảm…"
    - "Cung hoàng đạo…"

    Đây là bài hướng dẫn hành động trong ngày.
    """
  end

  defp tuvi_prompt2_content do
    """
    YÊU CẦU NỘI DUNG (RẤT QUAN TRỌNG):

    - Đây là bài viết CHỈ tập trung vào: NHỮNG VIỆC KHÔNG NÊN LÀM TRONG NGÀY.
    - Không viết nội dung tích cực chung chung.
    - Không viết về cung hoàng đạo.
    - Không viết lan sang vận mệnh dài hạn.

    FORMAT TIÊU ĐỀ (NGÀY XẤU – GIẬT GÂN, CẢNH BÁO MẠNH):
    - Tiêu đề phải gây chú ý, tạo cảm giác "phải đọc để tránh rủi ro", dùng từ cảnh báo rõ ràng (tránh ngay, kỵ, dễ hao tài, dễ thất bát…).
    - Cấu trúc gợi ý: "Ngày [Cảnh báo mạnh]: [Việc nguy hiểm/cần tránh] – [Hậu quả hoặc lời khuyên gây tò mò] (DD/MM/YYYY)"
    - Ví dụ giật gân: "Cảnh Báo: Ngày Này Khai Trương Dễ Phá Sản – Xem Ngay Để Tránh Hao Tài (04/03/2026)"
    - Ví dụ: "Ngày Đại Kỵ: Động Thổ, Cưới Hỏi Dễ Gặp Họa – Đừng Coi Thường Tử Vi (05/03/2026)"
    - Ví dụ: "Tử Vi 06/03: Ngày Hắc Đạo – Làm Việc Lớn Dễ Thất Bát, Đọc Để Biết Tránh (06/03/2026)"
    - Ví dụ: "Ngày Cần Thận: Ký Hợp Đồng Hôm Nay Dễ Tranh Chấp – Xem Chi Tiết Trong Bài (07/03/2026)"
    - DD/MM/YYYY lấy từ ngày dương lịch trong block thông tin ngày. Tiêu đề phải kết thúc bằng (ngày).

    Bắt buộc nội dung:
    - Phân tích rõ vì sao ngày này có hung tinh / trực xấu / sao xấu
    - Giải thích cụ thể từng việc nên tránh: động thổ, cưới hỏi, ký hợp đồng, khai trương…
    - Nếu là ngày Hoàng đạo nhưng có sao xấu → phải giải thích rõ điểm cần thận trọng
    - Nội dung tập trung vào cảnh báo và lý do

    Không được viết:
    - "Hôm nay chuyện tình cảm không thuận lợi…"
    - "Bạn có thể gặp xui xẻo…"
    - "Cung X nên tránh…"

    Đây là bài phân tích kiêng kỵ trong ngày theo tử vi cổ truyền.
    """
  end

  defp do_call_api(prompt_with_format) do
    api_key = Application.get_env(:modai_backend, ModaiBackendWeb.Endpoint)[:API_KEY_GEMINI] || ""
    url_gemini = Application.get_env(:modai_backend, ModaiBackendWeb.Endpoint)[:URL_GEMINI] || ""

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
        url =
          if String.starts_with?(url_gemini, "http://") or
               String.starts_with?(url_gemini, "https://") do
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
                # Gọi hàm parse_response_text
                {:ok, parse_response_text(response_text)}

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
    cleaned_text =
      response_text
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
    # Thay thế nhiều dòng trống liên tiếp bằng 2 dòng trống
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end
end
