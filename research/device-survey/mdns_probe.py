"""Send a one-shot (legacy unicast) mDNS PTR query and print which hosts answer.

Usage: python3 -I mdns_probe.py _airplay._tcp.local [seconds]
"""
import socket
import struct
import sys
import time


def encode_name(name):
    out = b""
    for label in name.rstrip(".").split("."):
        out += bytes([len(label)]) + label.encode()
    return out + b"\x00"


def main():
    service = sys.argv[1]
    wait = float(sys.argv[2]) if len(sys.argv) > 2 else 3.0
    query = struct.pack("!HHHHHH", 0x1234, 0, 1, 0, 0, 0) + encode_name(service) + struct.pack("!HH", 12, 1)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 255)
    sock.bind(("0.0.0.0", 0))
    sock.settimeout(0.5)
    sock.sendto(query, ("224.0.0.251", 5353))
    seen = {}
    end = time.time() + wait
    while time.time() < end:
        try:
            data, (host, _port) = sock.recvfrom(9000)
        except socket.timeout:
            continue
        seen.setdefault(host, len(data))
    for host, size in sorted(seen.items()):
        print(f"{host} answered ({size} bytes)")
    if not seen:
        print("no answers")


if __name__ == "__main__":
    main()
