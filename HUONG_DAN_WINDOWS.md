# Cài và sử dụng PDF2MD trên Windows

## Cài lần đầu

Yêu cầu: Windows 10/11 bản 64-bit (x64 hoặc ARM64), kết nối Internet và đủ dung lượng để tải thư viện, Node.js và tạo bản build.

1. Tải [ZIP của repo](https://github.com/dothanhdat1413/pdf2md/archive/refs/heads/main.zip).
2. Nhấp chuột phải vào ZIP → **Extract All / Giải nén tất cả**. Đặt thư mục ở vị trí bạn có quyền ghi, chẳng hạn Documents. Không chạy script ngay bên trong ZIP.
3. Mở thư mục đã giải nén và nhấp đúp **setup.bat**.
4. Đợi script báo cài đặt thành công. Lần đầu có thể mất vài phút; không đóng cửa sổ khi đang tải hoặc build.

Bạn không cần cài Git hay tự gõ lệnh npm. Script dùng Node.js có sẵn nếu phù hợp, hoặc tải Node.js LTS từ trang chính thức, kiểm tra SHA-256 và lưu riêng trong thư mục dự án. Không cần quyền quản trị để cài bản Node.js này.

## Mở ứng dụng mỗi lần dùng

Nhấp đúp **Mo_chay.bat**. Script chạy máy chủ trên máy của bạn và tự mở trình duyệt. Bình thường địa chỉ là `http://localhost:3000`; nếu cổng đã được ứng dụng khác sử dụng, xem địa chỉ được in trong cửa sổ.

- Chọn hoặc kéo thả nhiều PDF, tối đa 10 MB cho mỗi tệp.
- Bấm **Convert** để xử lý. Tệp lỗi không làm dừng những tệp còn lại.
- Tải riêng từng Markdown hoặc bấm **Download all (.zip)** để tải toàn bộ kết quả thành công.
- Giữ cửa sổ chạy ứng dụng mở trong lúc sử dụng. Nhấn **Ctrl+C** để dừng máy chủ.

Máy chủ chỉ lắng nghe trên máy hiện tại. Không cần chờ GitHub, PR hay quyền triển khai Vercel để sử dụng ứng dụng này.

## Cài lại, cập nhật hoặc chuyển máy

Nếu tải bản mã nguồn mới, giải nén rồi chạy lại **setup.bat** trước khi mở ứng dụng. Script có thể chạy lại để cài thư viện và tạo lại bản build.

Trên máy khác, tải ZIP và lặp lại bước cài lần đầu. Không cần chép `node_modules`, `.next` hoặc `.tools` từ máy cũ.

## Khi gặp lỗi

- **Không thấy file `.bat`:** bật **View → Show → File name extensions** trong File Explorer; tìm file có tên `setup` hoặc `Mo_chay`.
- **Cửa sổ báo lỗi tải:** kiểm tra Internet, proxy hoặc phần mềm bảo vệ trên máy, rồi chạy lại `setup.bat`.
- **Lỗi quyền ghi:** giải nén vào thư mục riêng của bạn, không đặt dưới `Program Files` hay thư mục hệ thống.
- **Thiếu thư viện hoặc bản build:** chạy lại `setup.bat`.
- **Máy do tổ chức quản lý chặn PowerShell:** cần người quản trị máy cho phép chạy script. Các file BAT chỉ đặt ExecutionPolicy cho tiến trình hiện tại, không thay đổi chính sách của máy.

Khi cần hỗ trợ, sao chép thông báo lỗi trong cửa sổ script để biết bước nào thất bại.
