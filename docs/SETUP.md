# Thiết lập chữ ký APK một lần

Không cần Google Play. Android vẫn yêu cầu cùng package và cùng chứng chỉ để cài nâng cấp mà không xóa dữ liệu.

## Cách nhanh (Linux/macOS/Git Bash có Java, OpenSSL và GitHub CLI)

```sh
gh auth login
git clone https://github.com/bannie-test/thu-ki-lam-viec.git
cd thu-ki-lam-viec
bash scripts/setup-signing.sh
gh workflow run android.yml --repo bannie-test/thu-ki-lam-viec
```

Script tạo khóa một lần trong `signing-backup/` (đã bị gitignore), tạo mật khẩu ngẫu nhiên và đưa 5 Secrets vào GitHub qua gh. Sao lưu RIÊNG `nhac-viec.jks` và `password.txt` vào nơi bền vững do bạn quản lý. Không đăng vào repo, issue hoặc chat. Chạy lại vào thư mục có khóa sẽ bị từ chối để tránh vô tình đổi chữ ký.

Nếu dùng Windows PowerShell: có thể chạy bằng Git Bash sau khi cài Java, OpenSSL, gh; hoặc tự tạo bằng `keytool` và điền Secrets thủ công trong Settings → Secrets and variables → Actions.

## Secrets bắt buộc

| Tên | Giá trị |
|---|---|
| ANDROID_KEYSTORE_BASE64 | Base64 của toàn bộ file nhac-viec.jks |
| ANDROID_STORE_PASSWORD | Mật khẩu keystore |
| ANDROID_KEY_PASSWORD | Mật khẩu khóa (script dùng cùng mật khẩu keystore) |
| ANDROID_KEY_ALIAS | nhac-viec |
| ANDROID_CERT_SHA256 | SHA-256 của chứng chỉ, không phải hash file keystore |

Khóa ký APK khác hoàn toàn khóa OpenAI API. Khóa OpenAI nhập trên điện thoại, không đặt vào GitHub Secrets cho build.

## Tải APK

Repo → Actions → **Build nhac-viec.apk** → run thành công → Artifacts → **nhac-viec** → giải nén → mở **nhac-viec.apk** trên Android. Cho phép cài ứng dụng từ nguồn đang mở APK nếu máy hỏi. Artifact giữ 30 ngày; có thể chạy lại workflow để build lại.

## Các bản cập nhật

- Push main tự build. Package luôn là `vn.bannie.nhac_viec`.
- Mã phiên bản dùng số giây tính từ 01/01/2020 tại lúc build, tăng theo thời gian, không bị reset khi đổi tên workflow. Có giới hạn Android int32 vào khoảng năm 2088; không dùng bản cũ hơn để ghi đè bản mới.
- Keystore và fingerprint phải giữ nguyên. Workflow không tạo khóa mới, không dùng cache hoặc artifact hết hạn để giữ khóa.
- Nếu thay máy/tài khoản, khôi phục đúng 5 Secrets từ bản sao khóa cũ.
- Mất khóa: không thể cài đè bản cũ. Không gỡ app để thử nếu cần giữ dữ liệu.
- Thiếu Secrets: check vẫn chạy; job APK dừng với lỗi hướng dẫn cụ thể. Không có APK release cho đến khi thiết lập xong.
