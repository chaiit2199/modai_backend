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

## Env trên server

- `CHECK_ORIGIN`: danh sách domain được phép (vd `//99tek.com,//lichtot365.com`).
- `USE_REFERER_FALLBACK=true`: khi không có Origin, dùng Referer để so whitelist (đã set trong `rel/env.sh.eex`).

Khi Nginx đã forward đúng Origin/Referer và env đúng, hành vi trên server sẽ giống local: cho phép domain trong whitelist, chặn 403 domain khác.
