��    Q      �  m   ,      �  �  �  `   �
  b   �
  p   ]  #   �     �          &  )   <  	   f  3   p     �  �   �      O  ,   p  $   �     �      �     �       #   7  !   [     }     �  %   �     �     �     
           7     F     Z     q     �  �   �  &   k     �     �     �  �   �  d   �     %  $   <  u   a  C   �  =        Y  &   r  +   �     �  (   �  )   �     )     B    \  (   d  /  �  �   �  .   y  F   �  "   �  -        @  
   `     k  2   ~  $   �  ,   �  '     '   +     S     Z  +   n     �     �     �     �     �     �     �  �  �  &  �  �   %  �   �%  �   &  *   �&  &   �&  %   '  %   ='  \   c'     �'  P   �'  !   !(  �   C(  9   �(  A   1)  7   s)  %   �)  '   �)  0   �)  *   **  1   U*  1   �*  /   �*  9   �*  2   #+  5   V+  *   �+  &   �+  "   �+     ,  ,   ,  -   L,  C   z,  7   �,  �   �,  7   �-  &   .  "   D.  .   g.    �.  k   �/     0  -   '0  �   U0  X   !1  X   z1  (   �1  /   �1  B   ,2     o2  2   �2  9   �2  -   �2  &   3  �  D3  5   �8  �  9    �;  K   �<  ^   .=  @   �=  W   �=  &   &>     M>     Y>  B   l>  *   �>  G   �>  -   "?  -   P?     ~?     �?  :   �?     �?     �?     @     @      @  
   3@     >@         P   K   ;               $   (   E       D                  8      -   )                 N   6      <   F         O           4             5       7                    ,      
   J                     Q              1       2   %      #       G   '             +   C          0   H   "      =       &   M   :   9          L   /       !                  	      *   @       ?   I   3   >   .   B   A           killall -l, --list
       killall -V, --version

  -e,--exact          require exact match for very long names
  -I,--ignore-case    case insensitive process name match
  -g,--process-group  kill process group instead of process
  -y,--younger-than   kill processes younger than TIME
  -o,--older-than     kill processes older than TIME
  -i,--interactive    ask for confirmation before killing
  -l,--list           list all known signal names
  -q,--quiet          don't print complaints
  -r,--regexp         interpret NAME as an extended regular expression
  -s,--signal SIGNAL  send this signal instead of SIGTERM
  -u,--user USER      kill only process(es) running as USER
  -v,--verbose        report if the signal was successfully sent
  -V,--version        display version information
  -w,--wait           wait for processes to die
  -n,--ns PID         match processes that belong to the same namespaces
                      as PID
   -                     reset options

  udp/tcp names: [local_port][,[rmt_host][,[rmt_port]]]

   -4,--ipv4             search IPv4 sockets only
  -6,--ipv6             search IPv6 sockets only
   -Z,--context REGEXP kill only process(es) having context
                      (must precede other arguments)
 %*s USER        PID ACCESS COMMAND
 %s is empty (not mounted ?)
 %s: Invalid option %s
 %s: no process found
 %s: unknown signal; %s -l lists signals.
 (unknown) /proc is not mounted, cannot stat /proc/self/stat.
 Bad regular expression: %s
 CPU Times
  This Process    (user system guest blkio): %6.2f %6.2f %6.2f %6.2f
  Child processes (user system guest):       %6.2f %6.2f %6.2f
 Can't get terminal capabilities
 Cannot allocate memory for matched proc: %s
 Cannot find socket's device number.
 Cannot find user %s
 Cannot open /proc directory: %s
 Cannot open /proc/net/unix: %s
 Cannot open a network socket.
 Cannot open protocol file "%s": %s
 Cannot resolve local port %s: %s
 Cannot stat %s: %s
 Cannot stat file %s: %s
 Copyright (C) 2007 Trent Waddington

 Could not kill process %d: %s
 Error attaching to pid %i
 Invalid namespace PID Invalid namespace name Invalid option Invalid time format Kill %s(%s%d) ? (y/N)  Kill process %d ? (y/N)  Killed %s(%s%d) with signal %d
 Memory
  Vsize:       %-10s
  RSS:         %-10s 		 RSS Limit: %s
  Code Start:  %#-10lx		 Code Stop:  %#-10lx
  Stack Start: %#-10lx
  Stack Pointer (ESP): %#10lx	 Inst Pointer (EIP): %#10lx
 Namespace option requires an argument. No process specification given No processes found.
 No such user name: %s
 PSmisc comes with ABSOLUTELY NO WARRANTY.
This is free software, and you are welcome to redistribute it under
the terms of the GNU General Public License.
For more information about these matters, see the files named COPYING.
 Page Faults
  This Process    (minor major): %8lu  %8lu
  Child Processes (minor major): %8lu  %8lu
 Press return to close
 Process with pid %d does not exist.
 Process, Group and Session IDs
  Process ID: %d		  Parent ID: %d
    Group ID: %d		 Session ID: %d
  T Group ID: %d

 Process: %-14s		State: %c (%s)
  CPU#:  %-3d		TTY: %s	Threads: %ld
 Scheduling
  Policy: %s
  Nice:   %ld 		 RT Priority: %ld %s
 Signal %s(%s%d) ? (y/N)  Specified filename %s does not exist.
 Specified filename %s is not a mountpoint.
 TERM is not set
 Unable to allocate memory for proc_info
 Unable to open stat file for pid %d (%s)
 Unable to scan stat file Unknown local port AF %d
 Usage: fuser [-fIMuvw] [-a|-s] [-4|-6] [-c|-m|-n SPACE]
             [-k [-i] [-SIGNAL]] NAME...
       fuser -l
       fuser -V
Show which processes use the named files, sockets, or filesystems.

  -a,--all              display unused files too
  -i,--interactive      ask before killing (ignored without -k)
  -I,--inode            use always inodes to compare files
  -k,--kill             kill processes accessing the named file
  -l,--list-signals     list available signal names
  -m,--mount            show all processes using the named filesystems or
                        block device
  -M,--ismountpoint     fulfill request only if NAME is a mount point
  -n,--namespace SPACE  search in this name space (file, udp, or tcp)
  -s,--silent           silent operation
  -SIGNAL               send this signal instead of SIGKILL
  -u,--user             display user IDs
  -v,--verbose          verbose output
  -w,--writeonly        kill only processes with write access
  -V,--version          display version information
 Usage: killall [OPTION]... [--] NAME...
 Usage: peekfd [-8] [-n] [-c] [-d] [-V] [-h] <pid> [<fd> ..]
    -8, --eight-bit-clean        output 8 bit clean streams.
    -n, --no-headers             don't display read/write from fd headers.
    -c, --follow                 peek at any new child processes too.
    -t, --tgid                   peek at all threads where tgid equals <pid>.
    -d, --duplicates-removed     remove duplicate read/writes from the output.
    -V, --version                prints version info.
    -h, --help                   prints this help.

  Press CTRL-C to end output.
 Usage: prtstat [options] PID ...
       prtstat -V
Print information about a process
    -r,--raw       Raw display of information
    -V,--version   Display version information and exit
 You can only use files with mountpoint options You cannot search for only IPv4 and only IPv6 sockets at the same time You must provide at least one PID. all option cannot be used with silent option. asprintf in print_stat failed.
 disk sleep fuser (PSmisc) %s
 killall: %s lacks process entries (not mounted ?)
 killall: Bad regular expression: %s
 killall: Cannot get UID from process status
 killall: Maximum number of names is %d
 killall: skipping partial match %s(%d)
 paging peekfd (PSmisc) %s
 procfs file for %s namespace not available
 prtstat (PSmisc) %s
 pstree (PSmisc) %s
 running sleeping traced unknown zombie Project-Id-Version: psmisc 23.2
Report-Msgid-Bugs-To: csmall@dropbear.xyz
PO-Revision-Date: 2018-08-14 13:25+0700
Last-Translator: Trần Ngọc Quân <vnwildman@gmail.com>
Language-Team: Vietnamese <translation-team-vi@lists.sourceforge.net>
Language: vi
MIME-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 8bit
X-Bugs: Report translation errors to the Language-Team address.
Plural-Forms: nplurals=1; plural=0;
X-Generator: Gtranslator 2.91.7
X-Poedit-SourceCharset: utf-8
            killall -l, --list
           killall -V, --version
  -e,--exact          yêu cầu khớp chính xác với mọi tên rất dài
  -I,--ignore-case    không phân biệt HOA/thường khi khớp tên tiến trình
  -g,--process-group  buộc kết thúc nhóm tiến trình thay thế tiến trình
  -y,--younger-than   buộc kết thúc mỗi tiến trình mới hơn THỜI_GIAN
  -o,--older-than     buộc kết thúc mỗi tiến trình cũ hơn THỜI_GIAN
  -i,--interactive    xin xác nhận trước khi buộc kết thúc
  -l,--list           liệt kê mọi tên tín hiệu đã biết
  -q,--quiet          không hiển thị lời than phiền (_im_)
  -r,--regexp         giải thích TÊN là biểu thức chính quy mở rộng
  -s,--signal TÍN_HIỆU gửi tín hiệu này thay thế SIGTERM
  -u,--user NG_DÙNG   buộc kết thúc chỉ những tiến trình đang chạy
                        dưới tư cách người dùng này
  -v,--verbose        thông báo khi đã gửi tín hiệu thành công
  -V,--version        hiện thông tin phiên bản của chương trình
  -w,--wait           đợi tiến trình kết thúc
  -n,--ns PID         khớp mẫu tiết trình cái mà thuộc về cùng một không
                      gian tên với PID
   -                     đặt lại các tùy chọn

  Các tên udp/tcp: [cổng_cục_bộ][,[máy_chủ][,[cổng_máy_chủ]]]

   -4,--ipv4             chỉ tìm kiếm ổ cắm kiểu IPv4
  -6,--ipv6             chỉ tìm kiếm ổ cắm kiểu IPv6
   -Z,--context BIỂU_THỨC_CHÍNH _QUY chỉ buộc kết thúc những tiến trình
                        có ngữ cảnh (phải đi trước các đối số khác)
 %*s NGƯỜI_DÙNG  PID TRUY_CẬP LỆNH
 %s trống rỗng (đã gắn chưa?)
 %s: Tùy chọn %s không hợp lệ
 %s: không tìm thấy tiến trình
 %s: không hiểu tín hiệu; câu lệnh "%s -l" giúp bạn liệt kê các tín hiệu.
 (không hiểu) Chưa gắn "/proc" thì không thể lấy thống kê về "/proc/self/stat".
 Biểu thức chính quy sai: %s
 Thời gian sử dụng CPU
    Tiến trình này (ngdùng hệ khách khốiVR):  %6.2f %6.2f %6.2f %6.2f
    Tiến trình con (ngdùng hệ khách):         %6.2f %6.2f %6.2f
 Không thể lấy khả năng của thiết bị cuối
 Không thể cấp phát bộ nhớ cho tiến trình khớp: %s
 Không tìm thấy số hiệu thiết bị ổ cắm.
 Không tìm thấy người dùng %s
 Không thể mở thư mục /proc: %s
 Không thể mở thư mục /proc/net/unix: %s
 Không thể mở một ổ cắm mạng.
 Không thể mở tập tin giao thức "%s": %s
 Không tìm thấy tên cổng cục bộ %s: %s
 Không thể lấy các thông tin về %s: %s
 Không thể lấy các thông tin về tập tin %s: %s
 Tác quyền © năm 2007 của Trent Waddington

 Không thể buộc kết thúc tiến trình %d: %s
 Gặp lỗi khi đính kèm đến PID %i
 IID không gian tên không hợp lệ Tên miền tên không hợp lệ Tùy chọn không hợp lệ Định dạng thời gian không hợp lệ Có buộc kết thúc %s(%s%d) không? (c/K) Có buộc kết thúc tiến trình %d không? (y/N) (có/không)  Mới buộc kết thúc %s(%s%d) với tín hiệu %d
 Bộ nhớ
  Cỡ ảo:        %-10s
  RSS:          %-10s		 Giới hạn RSS: %s
  Đầu mã:       %#-10lx		 Cuối mã: %#-10lx
  Đầu ngăn xếp: %#-10lx
  Con trỏ ngăn xếp (ESP): %#10lx	 Con trỏ thể hiện (EIP): %#10lx
 Tùy chọn miền tên cần đến một đối số. Chưa nhập đặc tả tiến trình Không tìm thấy tiến trình.
 Không có tên người dùng như vậy: %s
 PSmisc KHÔNG BẢO ĐẢM GÌ CẢ.
Đây là phần mềm tự do, và bạn có thể phân phối nó với điều kiện của
Giấy Phép Công của Gnu (GPL).
Để tìm thấy thông tin thêm thì hãy xem tập tin có tên COPYING (Giấy phép)
 Sai trang
    Tiến trình này	(nhỏ lớn): %8lu  %8lu
    Tiến trình con	(nhỏ lớn): %8lu  %8lu
 Bấm phím Enter để đóng
 Tiến trình có PID %d không tồn tại.
 Mã số cho tiến trình, nhóm và phiên làm việc
  Mã số tiến trình: %d	        Mã số cha mẹ: %d
        Mã số nhóm: %d	Mã số phiên làm việc: %d
      Mã số nhóm T: %d

 Tiến trình: %-14s		Tình trạng: %c (%s)
  CPU#:  %-3d		TTY: %s	Tuyến trình: %ld
 Định thời
   Chính sách: %s
  Mức ưu tiên: %ld 		 Mức ưu tiên RT: %ld %s
 Tín hiệu %s(%s%d) không? (y/N)(c/K)  Tên tập tin đã cho %s không tồn tại.
 Tên tập tin đã cho %s không phải là một điểm gắn.
 Chưa đặt TERM
 Không thể cấp phát bộ nhớ cho proc_info
 Không thể mở tập tin thống kê về PID %d (%s)
 Không thể mở quét tập tin thống kê Không biết cổng cục bộ AF %d
 Cách dùng: fuser [ -fMuvw ] [-a|-s] [-4|-6] [-c|-m|-n KHOẢNG]
                 [-k [-i] [-TÍN_HIỆU]] TÊN…
           fuser -l
           fuser -V
Hiển thị những tiến trình nào đang dùng những tập tin, ổ cắm hay hệ thống tập tin có tên đưa ra.

  -a,--all              cũng hiển thị các tập tin không dùng
  -i,--interactive      hỏi trước khi buộc kết thúc (bị bỏ qua nếu không có "-k")
  -I,--inode            luôn dùng nút để so sánh các tập tin
  -k,--kill             buộc kết thúc mỗi tiến trình đang truy cập đến tập tin có tên đưa ra
  -l,--list-signals     liệt kê những tên tín hiệu sẵn có
  -m,--mount            hiển thị tất cả các tiến trình đang sử dụng
                          những hệ thống tập tin hay thiết bị khối
  -M,--ismountpoint     đáp ứng chỉ khi TÊN là một điểm gắn (moutpoint)
  -n,--namespace KHOẢNG tìm kiếm trong miền tên này (file, udp hay tcp)
  -s,--silent           không xuất chi tiết
  -SIGNAL               gửi tín hiệu này thay cho SIGKILL
  -u,--user             hiển thị các mã người dùng (UID)
  -v,--verbose          kết xuất chi tiết
  -w,--writeonly        chỉ buộc chấm dứt những tiến trình mà có quyền ghi
  -V,--version          hiển thị thông tin về phiên bản
 Cách dùng: killall [ TÙY_CHỌN ]… [--] TÊN…
 Cách dùng: peekfd [-8] [-n] [-c] [-d] [-V] [-h] <pid> [<fd> ..]
    -8, --eight-bit-clean        xuất luồng dữ liệu sạch 8 bít.
    -n, --no-headers             không hiển thị đọc/viết từ phần đầu fd.
    -c, --follow                 xem bất kỳ tiến trình con mới nào.
    -t, --tgid                   xem tất cả các tiến trình chỗ mà tgid bằng <pid>.
    -d, --duplicates-removed     gỡ bỏ đọc/viết trùng lặp ra khỏi kết xuất.
    -V, --version                hiển thị thông tin về phiên bản.
    -h, --help                   hiển thị trợ giúp này.

  Bấm tổ hợp phím CTRL-C để kết thúc.
 Cách dùng: prtstat [tùy_chọn…] PID …
           prtstat -V
(PID là mã số tiến trình)

In ra thông tin về một tiến trình nào đó
    -r,--raw       Hiển thị thông tin dạng thô
    -V,--version   Hiển thị thông tin về phiên bản rồi thoát
 Bạn có thể sử dụng tập tin chỉ với tùy chọn điểm_lắp Không cho phép bạn tìm kiếm ổ cắm kiểu cả IPv4 lẫn IPv6 đều đồng thời Phải cung cấp ít nhất một PID (mã số tiến trình). tất cả các tùy chọn không cho phép bạn dùng với tùy chọn "im lặng". asprintf trong print_stat bị lỗi.
 đĩa ngủ fuser (PSmisc) %s
 killall: %s thiếu các mục tuyến trình (đã gắn chưa?)
 killall: Biểu thức chính quy sai: %s
 killall: Không thể lấy UID từ trạng thái của tiến trình
 killall: Số lượng tên tối đa là %d
 killall: bỏ qua khớp một phần %s(%d)
 đang dàn trang peekfd (PSmisc) %s
 tập tin procfs cho không gian tên %s không sẵn có
 prtstat (PSmisc) %s
 pstree (PSmisc) %s
 đang chạy đang ngủ được theo dõi không rõ ma 