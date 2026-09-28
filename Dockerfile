# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization
#
# Dưới đây là Dockerfile "chạy được nhưng chưa production": một stage,
# chạy bằng user root, không có health check, base image nặng.
#
# NHIỆM VỤ: sửa file này thành bản production-ready. Yêu cầu:
#   [x] Multi-stage build: stage `builder` cài dependency, stage runtime
#       chỉ copy kết quả sang → image nhỏ hơn, không mang theo compiler.
#       Cú pháp: `FROM python:3.11-slim AS builder`
#   [x] Base image slim (hoặc alpine), không dùng `python:3.11` bản đầy đủ
#   [x] COPY requirements.txt và pip install TRƯỚC khi COPY source code
#       (Docker cache theo layer: sửa 1 dòng code không phải cài lại thư viện)
#   [x] Tạo user thường và chuyển sang bằng lệnh `USER` — container chạy
#       root nghĩa là ai thoát được khỏi app cũng thành root trên host
#   [x] Có `HEALTHCHECK` gọi vào endpoint /health
#   [x] Đọc cổng từ biến môi trường PORT (cloud tự gán cổng, không cố định 8000)
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài dependency, stage này bị vứt đi sau khi build ──
FROM python:3.11-slim AS builder

WORKDIR /build

# Chỉ copy requirements.txt trước: layer pip install được cache cho tới khi
# requirements.txt đổi, sửa code không làm cài lại thư viện.
COPY requirements.txt .
RUN pip install --no-cache-dir --timeout 120 --retries 10 --prefix=/install -r requirements.txt


# ── Stage 2: runtime — chỉ chứa Python + thư viện đã cài + code ──
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

# Lấy KẾT QUẢ cài đặt từ builder, không mang theo pip cache hay file build
COPY --from=builder /install /usr/local

RUN useradd --create-home --uid 10001 appuser

# Code copy SAU cùng — đây là layer đổi thường xuyên nhất
COPY --chown=appuser:appuser utils ./utils
COPY --chown=appuser:appuser app ./app

USER appuser

EXPOSE 8000

# Image slim không có curl → dùng chính Python để gọi /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/health' % os.getenv('PORT', '8000'), timeout=4)" || exit 1

# sh -c để nội suy $PORT; `exec` để uvicorn thay sh làm PID 1 và nhận SIGTERM trực tiếp
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
