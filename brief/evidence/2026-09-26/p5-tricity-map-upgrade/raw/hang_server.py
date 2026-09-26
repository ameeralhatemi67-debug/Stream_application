"""Accepts TCP connections on 127.0.0.1:<port> and never answers (a connected network without internet)."""
import socket, sys, threading, time
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", int(sys.argv[1]))); s.listen(64)
held = []
while True:
    c, _ = s.accept(); held.append(c)
