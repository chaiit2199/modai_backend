# Nginx: Forward Origin & Referer để OriginAllowlist hoạt động trên server

Trên local, request từ browser có header `Origin` → app kiểm tra whitelist → chặn 403 đúng.

Trên server, **Nginx mặc định có thể không chuyển tiếp** `Origin` và `Referer` xuống app → app nhận `origin_value = nil` → 403 (missing_origin) cho mọi request, hoặc không có đủ thông tin để chặn domain lạ.

## Cấu hình Nginx (block `location` proxy tới Phoenix)

Thêm **trong block `location`** proxy tới backend (vd `proxy_pass http://127.0.0.1:8088;`):

```nginx
# Bắt buộc: chuyển Origin và Referer xuống app để:
# - Cho phép request từ domain trong whitelist (Origin hoặc Referer khớp)
# - Chặn 403 request từ domain khác (Origin không trong whitelist)
proxy_set_header Origin $http_origin;
proxy_set_header Referer $http_referer;

# Các header thường có sẵn, giữ nguyên nếu đã có
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

Sau đó reload Nginx:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

## Kiểm tra trên server

1. **Xem log app khi bị 403**  
   Log có dạng: `OriginAllowlist 403 reason=missing_origin path=/api/login headers=%{}`  
   - `headers=%{}` → app **không** nhận Origin/Referer → Nginx chưa forward đúng.  
   - `headers=%{"origin" => "https://...", "referer" => "..."}` → app đã nhận → Nginx đã cấu hình đúng.

2. **Test chặn domain lạ (phải trả 403):**
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" \
     -X POST \
     -H "Origin: https://evil.com" \
     -H "Content-Type: application/json" \
     -d '{"username":"x","password":"y"}' \
     "https://99tek.com/api/login"
   ```
   Kỳ vọng: `403`.

3. **Test domain trong whitelist (không bị 403 do origin):**
   ```bash
   curl -s -o /dev/null -w "%{http_code}\n" \
     -X POST \
     -H "Origin: https://www.lichtot365.com" \
     -H "Content-Type: application/json" \
     -d '{"username":"x","password":"y"}' \
     "https://99tek.com/api/login"
   ```
   Kỳ vọng: `401` (sai user/pass) hoặc `200`, **không** phải `403`.

## Cách lấy origin khi request không có Origin/Referer

App đọc origin theo thứ tự: **Origin** → **header fallback** (cấu hình) → **Referer**. Nếu cả ba đều không có → 403 missing_origin.

### 1. Bật Referer fallback (request từ browser)

Trên server set env:
```bash
export USE_REFERER_FALLBACK="true"
```
(Đã có trong `rel/env.sh.eex`.) Khi đó nếu request **không** có `Origin` nhưng có `Referer` (trình duyệt gửi), app sẽ dùng Referer để so whitelist.

### 2. Frontend gửi header chứa origin (chủ động)

Khi gọi API từ **JavaScript trong browser**, có thể gửi thêm header với origin của trang:

```javascript
// fetch
fetch(apiUrl, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'X-Requested-Origin': window.origin   // vd "https://www.lichtot365.com"
  },
  body: JSON.stringify({ username, password })
});

// axios
axios.post(apiUrl, data, {
  headers: { 'X-Requested-Origin': window.origin }
});
```

Trên server (env khi start app):
```bash
export ORIGIN_FALLBACK_HEADER="x-requested-origin"
```

App sẽ đọc header `X-Requested-Origin` khi không có `Origin` và dùng giá trị đó để so whitelist. Chỉ dùng với frontend chạy trên domain bạn kiểm soát (whitelist vẫn chặn domain lạ).

Khi 403 missing_origin, log sẽ in `headers=...` (origin, referer, x-requested-origin, x-original-origin) để xem request đang có header nào.

---

## Env trên server

- `CHECK_ORIGIN`: danh sách domain được phép (vd `//99tek.com,//lichtot365.com`).
- `USE_REFERER_FALLBACK=true`: khi không có Origin, dùng Referer để so whitelist (đã set trong `rel/env.sh.eex`).
- `ORIGIN_FALLBACK_HEADER=x-requested-origin`: (tùy chọn) đọc origin từ header này khi không có Origin (frontend gửi `X-Requested-Origin: window.origin`).

Khi Nginx đã forward đúng Origin/Referer và env đúng, hành vi trên server sẽ giống local: cho phép domain trong whitelist, chặn 403 domain khác.
