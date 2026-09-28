# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: viết câu trả lời ngay dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Do Thanh Tung  Mã học viên: 2A202602845

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống: khi deploy lên Railway mình quên set AGENT_API_KEY. Nhờ không có giá trị mặc định, app dừng ngay lúc khởi động với lỗi ValidationError agent_api_key Field required. Mình thấy lỗi trong log và set biến trước khi có ai dùng.

Nếu để mặc định changeme thì app vẫn chạy bình thường trên URL công khai. Chữ changeme lại nằm trong code của repo public nên ai đọc repo cũng biết khóa, gọi /ask thoải mái và tiêu hết ngân sách của mình. Mình chỉ phát hiện ra khi đã mất tiền.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log thu được khi gọi /ask:

{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T09:17:52.129632+00:00", "user_id": "demo-cp4", "tokens_in": 3, "tokens_out": 37, "cost_usd": 2.265e-05}

Hai việc làm được mà print không làm được:
1. Lọc theo trường: tìm tất cả request của user_id demo-cp4, hoặc chỉ xem các dòng level error.
2. Tính toán và cảnh báo: cộng cost_usd theo từng user trong ngày, hoặc đặt cảnh báo khi tokens_in tăng bất thường. Dòng print chỉ là chữ cho người đọc, máy không tách được từng giá trị.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1730 MB (1.73 GB) |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Giải thích: bản multi-stage nhỏ hơn khoảng 1460 MB, tức chỉ bằng khoảng 16 phần trăm bản 1 stage. Bản 1 stage dùng python:3.11 đầy đủ, trong đó có sẵn compiler gcc, header để build thư viện C, git và nhiều gói hệ điều hành mà app không cần khi chạy. Nó còn giữ pip cache và copy cả thư mục tests, tài liệu vào image.

Bản multi-stage dùng python:3.11-slim, chỉ copy thư viện đã cài từ stage builder sang cùng hai thư mục app và utils. Phần chênh lệch chính là công cụ build và gói hệ điều hành dư thừa đó.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Mình thêm một dòng vào app/main.py rồi build lại. Kết quả: các layer FROM, WORKDIR, COPY requirements.txt, RUN pip install, useradd, COPY --from=builder và COPY utils đều CACHED. Chỉ layer COPY app chạy lại, build xong trong vài giây.

Nếu đặt COPY . . lên trước RUN pip install thì sửa một ký tự trong code cũng làm layer COPY thay đổi. Docker phải chạy lại mọi layer phía sau, tức cài lại toàn bộ thư viện mỗi lần build. Lần build đầu của mình mất khoảng 2 phút cho bước pip install, nên mỗi lần sửa code sẽ mất chừng đó thời gian.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện:
1. Code Python có lỗ hổng, ví dụ một thư viện cho phép chạy lệnh từ dữ liệu gửi lên.
2. Kẻ tấn công gửi request độc và chạy được lệnh shell bên trong container.
3. Vì container chạy bằng root nên lệnh đó có toàn quyền trong container: đọc biến môi trường chứa secret, cài thêm công cụ, sửa file hệ thống.
4. Root trong container cũng là uid 0 trên kernel của host. Chỉ cần thêm một lỗi thoát container, hoặc container có mount thư mục host hay docker.sock, kẻ tấn công thành root trên máy host.

Lệnh USER appuser cắt chuỗi ở bước 3. Lệnh của kẻ tấn công chỉ chạy với quyền uid 10001, không sửa được file hệ thống, không cài được gói. Nếu có thoát ra host thì cũng chỉ là một user thường không có quyền gì.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Tối đa 20 request trong 2 giây.

Cách làm: gửi 10 request lúc 10:00:59, đây là hạn mức của phút 10:00. Đến 10:01:00 bộ đếm reset về 0, gửi tiếp 10 request nữa cho phút 10:01. Tổng cộng 20 request chỉ trong khoảng 2 giây mà vẫn đúng luật.

Với sliding window, lúc 10:01:00 hệ thống vẫn đếm được 10 request trong 60 giây gần nhất nên chặn ngay, chỉ cho tối đa 10 request.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Khác nhau: rate limit đếm số lần gọi trong 60 giây, trả 429. Cost guard đếm số tiền đã tiêu trong tháng, trả 402.

Rate limit cho qua nhưng cost guard chặn: một user chỉ gửi 5 request mỗi phút nhưng mỗi câu hỏi rất dài, hàng chục nghìn token. Số lần gọi dưới 10 nên rate limit không chặn, nhưng tiền tiêu vượt 10 USD trong tháng nên cost guard trả 402.

Ngược lại: user gửi 15 câu ngắn liên tiếp trong 1 phút. Chi phí chỉ khoảng vài phần nghìn USD, còn rất xa ngân sách, nhưng từ request thứ 11 rate limit trả 429. Mình đã thấy đúng điều này trên bản deploy: 10 lần 200 rồi 5 lần 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện nếu gộp làm một và kiểm tra Redis:
1. Redis mất kết nối.
2. Cả 3 container cùng lúc trả lỗi ở health check, dù bản thân app vẫn sống.
3. Sau vài lần thử lại, orchestrator coi cả 3 là chết và restart cả 3 cùng lúc.
4. Trong lúc restart không còn container nào phục vụ, người dùng nhận lỗi 502.
5. Container mới lên nhưng Redis vẫn chưa về nên lại fail health check và tiếp tục bị restart.
6. Hết 30 giây Redis về lại, nhưng container còn đang khởi động nên dịch vụ chết lâu hơn 30 giây.

Nếu tách riêng: /health vẫn 200 nên không container nào bị restart, còn /ready trả 503 nên load balancer tạm ngừng gửi request. Redis về là /ready trả 200 và dịch vụ chạy lại ngay.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Mình chạy 3 container agent dùng chung một Redis và gọi /ask lần lượt vào agent1, agent2, agent3 với cùng X-User-Id. history_length nhận được là 0, 2, 4, 6, 8, 10. Con số tăng đều dù mỗi lần vào một container khác nhau, vì lịch sử nằm ở Redis.

Nếu lưu trong dict Python thì mỗi container có bộ nhớ riêng. Kết quả sẽ là 0, 0, 0, 2, 2, 2: mỗi container chỉ nhớ các lượt đi vào chính nó, agent như bị mất trí nhớ khi đổi container. Container nào restart thì lịch sử của nó cũng về 0.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Lỗi: sau khi deploy, mình gọi /ask có API key bằng curl trong Git Bash trên Windows với câu hỏi Deploy là gì. Service trả 400 Bad Request, nội dung There was an error parsing the body.

Tìm nguyên nhân: /health, /ready và /ask không có key đều đúng. Mình gửi lại với câu hỏi test không dấu thì được 200, nên lỗi không nằm ở service mà ở chữ tiếng Việt. Curl trong terminal Windows không gửi chữ có dấu dưới dạng UTF-8, nên JSON đến server bị hỏng.

Cách sửa: gửi body JSON bằng UTF-8 chuẩn, mình dùng Python httpx. Request trả 200 kèm câu trả lời. Mình cũng ghi chú điều này vào DEPLOYMENT.md.
