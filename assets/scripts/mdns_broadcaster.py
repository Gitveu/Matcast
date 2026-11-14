import sys
import socket
import time
from zeroconf import IPVersion, ServiceInfo, Zeroconf

def main():
    friendly_name = sys.argv[1] if len(sys.argv) > 1 else "Matcast-CyberPC"
    cast_port = int(sys.argv[2]) if len(sys.argv) > 2 else 8009
    rtsp_port = int(sys.argv[3]) if len(sys.argv) > 3 else 7236
    ip = sys.argv[4] if len(sys.argv) > 4 else "192.168.10.11"

    print(f"[MDNS Broadcaster] Initializing on {ip} for {friendly_name}")

    safe_name = friendly_name.replace(" ", "-").replace("(", "").replace(")", "")

    # 1. Google Cast (_googlecast._tcp)
    cast_desc = {
        'id': 'a1b2c3d4e5f678901234567890abcdef',
        'cd': 'a1b2c3d4e5f678901234567890abcdef',
        'rm': '',
        've': '05',
        'md': 'Chromecast',
        'ic': '/setup/icon.png',
        'fn': friendly_name,
        'ca': '4101',
        'st': '0',
        'bs': 'FA8FCA728345',
        'nf': '1',
        'rs': ''
    }
    cast_info = ServiceInfo(
        '_googlecast._tcp.local.',
        f"{safe_name}._googlecast._tcp.local.",
        addresses=[socket.inet_aton(ip)],
        port=cast_port,
        properties=cast_desc,
        server=f"{safe_name}.local.",
    )

    # 2. Wireless Display / Miracast over IP (_display._tcp)
    display_desc = {
        'wfd_video_formats': '00000001',
        'wfd_audio_codecs': '00000001',
        'fn': friendly_name,
    }
    display_info = ServiceInfo(
        '_display._tcp.local.',
        f"{safe_name}._display._tcp.local.",
        addresses=[socket.inet_aton(ip)],
        port=rtsp_port,
        properties=display_desc,
        server=f"{safe_name}.local.",
    )

    zc = Zeroconf(interfaces=[ip], ip_version=IPVersion.V4Only)
    zc.register_service(cast_info)
    zc.register_service(display_info)
    print(f"[MDNS Broadcaster] OK: {safe_name} registered on {ip} (Cast:{cast_port}, RTSP:{rtsp_port})")
    sys.stdout.flush()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        try:
            zc.unregister_service(cast_info)
            zc.unregister_service(display_info)
            zc.close()
        except Exception:
            pass

if __name__ == '__main__':
    main()
