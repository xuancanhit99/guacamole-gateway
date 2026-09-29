# Guacamole Gateway

Cổng remote desktop ưu tiên trình duyệt, được xây dựng từ các image chính thức
Apache Guacamole 1.6.0, guacd, PostgreSQL và Nginx. Sản phẩm cung cấp các phiên
RDP, VNC và SSH qua trình duyệt HTML5 mà không yêu cầu cài đặt ứng dụng khách.

## Kiến trúc

```text
Browser -> Nginx gateway -> Guacamole web app -> guacd -> RDP/VNC/SSH target
                              |
                              +-> PostgreSQL authentication and configuration
```

Chỉ Nginx công bố một cổng trên máy chủ. PostgreSQL, guacd và ứng dụng web
Guacamole vẫn nằm trong mạng Docker nội bộ. Địa chỉ lắng nghe mặc định là
`127.0.0.1:8080`; để truy cập từ xa, hãy dùng reverse proxy TLS hiện có, VPN
hoặc SSH tunnel.

## Khởi động nhanh

Yêu cầu: Docker Engine/Desktop có Compose v2, 2 GB RAM và phiên bản PowerShell
hoặc POSIX shell tương đối mới.

PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
./Install-GuacamoleGateway.ps1 -Start
```

This is an in-place portable installation: extract the signed/checksummed ZIP
to its final directory, then run the installer there. It verifies Docker,
creates `.env` with random credentials, validates Compose, and optionally starts
the stack. `Start-GuacamoleGateway.ps1` is the short Windows start command for
later runs.

Linux/macOS:

```sh
chmod +x scripts/*.sh db/init/*.sh tests/*.sh
./scripts/setup.sh
./scripts/start.sh
```

Lệnh thiết lập chỉ in mật khẩu quản trị viên ban đầu được tạo ngẫu nhiên đúng
một lần. Mở <http://127.0.0.1:8080/guacamole/> rồi đăng nhập bằng `admin` (hoặc
tên người dùng đã truyền cho script thiết lập). Hãy bảo mật file `.env`.

Tạo kết nối sau khi đăng nhập:

1. Mở **Settings -> Connections -> New connection**.
2. Chọn RDP, VNC hoặc SSH rồi nhập hostname mà máy chạy Docker có thể truy cập.
3. Để truyền file qua RDP, bật drive và dùng `/drive` làm thư mục.
4. Để ghi lại phiên, dùng `/recordings`; ứng dụng web có thể tự phát hiện các bản ghi.

Các lệnh thường dùng:

```powershell
./scripts/status.ps1
./scripts/health-check.ps1
./scripts/backup.ps1
./scripts/stop.ps1
./tests/test-config.ps1
```

Các lệnh tương ứng trên POSIX có cùng tên nhưng dùng phần mở rộng `.sh`.

## Bản demo SSH end-to-end tùy chọn

Profile Compose `e2e` bổ sung một máy đích OpenSSH dùng một lần vào mạng Docker
nội bộ. Máy đích không công bố cổng nào trên máy chủ và nhận mật khẩu ngẫu nhiên
từ file `.env.e2e` đã được bỏ qua bởi Git. Profile này không được bật khi khởi
động bình thường.

PowerShell:

```powershell
./scripts/e2e-setup.ps1
./scripts/e2e-up.ps1 -RunSmoke
```

Linux/macOS (bài smoke test API/tunnel yêu cầu Python 3.9 trở lên):

```sh
./scripts/e2e-setup.sh
RUN_SMOKE=1 ./scripts/e2e-up.sh
```

Bài smoke test xác thực qua REST API, tạo hoặc cập nhật kết nối
`E2E SSH target` theo cách lặp lại an toàn, mở HTTP tunnel của Guacamole, kiểm
tra các chỉ thị của giao thức hiển thị, đồng thời yêu cầu cả sự kiện kết nối SSH
thành công của guacd và sự kiện chấp nhận đăng nhập của máy đích. Nhờ đó, bài
test chứng minh toàn bộ đường đi từ trình duyệt đến ứng dụng web, guacd rồi máy
đích SSH hoạt động, thay vì chỉ kiểm tra các cổng TCP đang mở.

Để chỉ tạo hoặc làm mới kết nối REST mà không mở tunnel, hãy chạy
`./scripts/e2e-create-connection.ps1` (hoặc lệnh tương ứng có phần mở rộng
`.sh`).

Để dừng và xóa riêng máy đích demo, đồng thời giữ nguyên mọi volume và dịch vụ
chính của sản phẩm:

```powershell
./scripts/e2e-down.ps1
```

Script dọn dẹp E2E chủ ý không xóa volume. Thiết kế này ngăn một thao tác E2E
vô tình xóa dữ liệu PostgreSQL của sản phẩm.

## Tham chiếu vận hành nhanh

Yêu cầu: Docker Engine/Desktop có Compose v2, tối thiểu 2 GB RAM, PowerShell
hoặc POSIX shell. Chạy:

```powershell
./scripts/setup.ps1
./scripts/start.ps1
```

Script `setup` tạo mật khẩu PostgreSQL và mật khẩu quản trị viên ngẫu nhiên,
sau đó chỉ in mật khẩu quản trị viên một lần. Truy cập
<http://127.0.0.1:8080/guacamole/>. Theo mặc định, gateway chỉ lắng nghe trên
loopback nên không vô tình công bố PostgreSQL hoặc remote desktop ra Internet.

Sau khi đăng nhập, vào **Settings -> Connections -> New connection**, chọn RDP,
VNC hoặc SSH. Địa chỉ đích phải truy cập được từ máy chạy Docker. Với RDP drive,
dùng `/drive`; với bản ghi phiên, dùng `/recordings`.

Các lệnh vận hành:

```powershell
./scripts/status.ps1       # xem trang thai container
./scripts/health-check.ps1 # kiem tra endpoint va security headers
./scripts/backup.ps1       # sao luu PostgreSQL custom dump vao backups/
./scripts/stop.ps1         # dung dich vu, khong xoa du lieu
./tests/test-config.ps1    # test cau hinh/security offline
```

Để kiểm thử end-to-end tùy chọn, chạy `./scripts/e2e-up.ps1 -RunSmoke`. Profile
`e2e` tạo một máy đích SSH nội bộ, không công bố cổng ra máy chủ, tạo kết nối qua
REST API và mở Guacamole tunnel thật. File `.env.e2e` chứa mật khẩu ngẫu nhiên
và đã được bỏ qua bởi Git.

## Mô hình bảo mật

- Các image dùng tag ổn định cụ thể: Guacamole/guacd `1.6.0`, PostgreSQL
  `17.11-alpine` và Nginx `1.28.3-alpine`.
- PostgreSQL không công bố cổng nào và mạng Docker backend là mạng nội bộ.
- Địa chỉ lắng nghe công khai chỉ bind vào loopback, trừ khi
  `GATEWAY_BIND` được chủ động thay đổi.
- Quá trình thiết lập tạo riêng hai secret ngẫu nhiên 288 bit cho cơ sở dữ liệu
  và quản trị viên.
- Tài khoản mặc định phổ biến `guacadmin/guacadmin` không bao giờ được tạo.
- Các container bật `no-new-privileges`; file log được xoay vòng.
- Nginx tắt response buffering cho tunnel và thiết lập các security header cơ bản.
- Dữ liệu cơ sở dữ liệu nằm trong named volume; mật khẩu nằm trong file `.env`
  đã được bỏ qua bởi Git.

Khi công bố dịch vụ lên Internet trong môi trường production, hãy kết thúc HTTPS
tại Caddy, Traefik, Nginx hoặc một load balancer được quản lý. Chuyển tiếp các
header `Host`, `X-Real-IP`, `X-Forwarded-For` và `X-Forwarded-Proto`. Không đổi
`GATEWAY_BIND` thành `0.0.0.0` nếu chưa có TLS và kiểm soát truy cập mạng. Nên
ưu tiên tuyến riêng qua Tailscale/WireGuard.

Bản triển khai không tự động quản lý thông tin đăng nhập của máy đích. Chỉ lưu
thông tin này trong Guacamole nếu mô hình vận hành yêu cầu; nếu không, hãy yêu
cầu người dùng nhập khi bắt đầu kết nối. Dùng các tài khoản riêng có quyền tối
thiểu trên hệ thống đích.

## Vòng đời cơ sở dữ liệu

File `db/init/001-create-schema.sql` trong repository là schema PostgreSQL chính
thức của Apache Guacamole 1.6.0 và giữ nguyên phần đầu giấy phép Apache. Script
khởi tạo tiếp theo tạo quản trị viên được yêu cầu theo định dạng mật khẩu SHA-256
của Guacamole. PostgreSQL chỉ chạy các file này khi data volume còn trống.

Để chủ động tạo lại hệ thống từ đầu, trước tiên hãy tạo bản sao lưu. Việc xóa
volume có tính phá hủy dữ liệu nên chủ ý không được đóng gói trong một script
tiện ích:

```sh
docker compose down
docker volume ls
# Verify the exact project volume before removing it manually.
```

Khi nâng cấp, `guacamole/guacamole` và `guacamole/guacd` phải luôn dùng cùng
phiên bản, đồng thời các script nâng cấp schema từ upstream phải được áp dụng
đúng thứ tự. Tuyệt đối không trỏ image có phiên bản major/minor mới vào dữ liệu
production trước khi tạo bản sao lưu và thử khôi phục thành công trong staging.

## Kiểm thử và xử lý sự cố

Việc xác thực tĩnh không yêu cầu khởi động container:

```powershell
./tests/test-config.ps1
```

Xác thực runtime sau khi khởi động:

```powershell
./tests/test-config.ps1 -Runtime
docker compose logs --tail=200 gateway guacamole guacd postgres
```

## Đóng gói bản phát hành

Bundle này là một sản phẩm Docker Compose, không phải ứng dụng desktop độc lập.
Trên Windows dùng `Install-GuacamoleGateway.ps1`; trên Linux/macOS dùng
`scripts/install.sh`. Cả hai đều xác minh Docker Compose, sinh credential ngẫu
nhiên được Git bỏ qua và có thể khởi động dịch vụ. `scripts/build-release.ps1`
(hoặc `.sh`) tạo ZIP, `tar.gz` và `SHA256SUMS.txt` trong `dist/`. Archive chủ ý
loại bỏ `.env`, `.env.e2e`, database backup, recording, drive data và trạng thái
Docker.

Chạy cổng kiểm soát release tại máy cục bộ:

```powershell
./scripts/release-audit.ps1
./scripts/build-release.ps1
Get-Content ./dist/SHA256SUMS.txt
```

`.github/workflows/release.yml` lặp lại việc kiểm tra Compose, giấy phép và
secret; dựng cả hai định dạng archive, xác minh checksum và chỉ phát hành GitHub
Release khi tag `guacamole-gateway-v*` khớp `VERSION` được push rõ ràng. Workflow
nằm trong thư mục sản phẩm để hoạt động ngay khi thư mục trở thành gốc của repo
Git riêng; bản thân nó không tự tạo repository.

Vì sao không có một `.exe` duy nhất? Guacamole là máy chủ nhiều container, cần
Docker, dữ liệu PostgreSQL, guacd, quyền truy cập mạng đích và xử lý
browser/WebSocket. Wrapper `.exe` vẫn phải phụ thuộc Docker Desktop cùng các
image, đồng thời làm việc cập nhật, ký mã và quản lý credential phức tạp hơn.
Sau này có thể bổ sung installer đã ký như một lớp tiện ích quanh bundle đã
được audit, nhưng Compose bundle vẫn là artifact triển khai có thẩm quyền.

Nếu stack từng được khởi động với các giá trị bootstrap không hợp lệ, việc sửa
`.env` sẽ không chạy lại quá trình khởi tạo vì PostgreSQL đã sở hữu một data
volume. Hãy sao lưu mọi dữ liệu có giá trị, sau đó chủ động tạo lại riêng volume
của đúng project đã được kiểm tra.

## Phạm vi và giấy phép

Sản phẩm này đóng gói các container và cấu hình từ upstream; sản phẩm không fork
Apache Guacamole. Guacamole và schema đi kèm dùng Apache-2.0. PostgreSQL dùng
PostgreSQL License và Nginx dùng BSD-2-Clause. Image OpenSSH E2E tùy chọn dùng
GPL-3.0-only và chỉ là dependency phục vụ kiểm thử, không thuộc runtime mặc
định. Hãy xem lại toàn bộ thông báo từ upstream trước khi phân phối lại.
