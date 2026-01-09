#!/usr/bin/env python3
"""
SSH-over-HTTP/2 relay client with Server-Sent Events (SSE).
Uses HTTP/2 for better performance than short-polling.

Usage: ssh -o ProxyCommand="python3 ssh_http2_relay.py <relay_url> [api_key]" user@host

Protocol:
  - POST /ssh/send: Send data to SSH (base64-encoded)
  - GET /ssh/stream: SSE stream for receiving data from SSH

Environment variables:
  SSH_RELAY_API_KEY: API key for relay authentication
  DEBUG: Set to '1' for verbose logging
"""

import sys
import os
import base64
import select
import time
import threading
import uuid
import fcntl
import ssl

# Try httpx for HTTP/2, fall back to urllib
try:
    import httpx
    HAS_HTTPX = True
except ImportError:
    import urllib.request
    import urllib.error
    HAS_HTTPX = False

SEND_TIMEOUT = 5.0
STREAM_TIMEOUT = 30.0  # SSE reconnect timeout
EOF_WAIT_TIME = 2.0

class SSHHttp2Relay:
    def __init__(self, relay_url, api_key=None):
        self.relay_url = relay_url.rstrip('/')
        self.session_id = str(uuid.uuid4())
        self.api_key = api_key
        self.running = True
        self.stdin_eof = False
        self.last_recv_time = time.time()
        self.debug = os.environ.get('DEBUG', '') == '1'

        # HTTP/2 client
        if HAS_HTTPX:
            self.client = httpx.Client(
                http2=True,
                verify=False,
                timeout=SEND_TIMEOUT
            )
        else:
            # Fall back to urllib (HTTP/1.1)
            self.ssl_context = ssl.create_default_context()
            self.ssl_context.check_hostname = False
            self.ssl_context.verify_mode = ssl.CERT_NONE
            self.client = None

    def log(self, msg):
        if self.debug:
            print(f"[H2-RELAY] {msg}", file=sys.stderr)
            sys.stderr.flush()

    def get_headers(self):
        headers = {'X-Session-ID': self.session_id}
        if self.api_key:
            headers['X-API-Key'] = self.api_key
        return headers

    def send_data(self, data):
        """Send data to SSH via HTTP/2 POST"""
        try:
            encoded = base64.b64encode(data).decode('ascii')
            url = f"{self.relay_url}/ssh/send"
            headers = self.get_headers()
            headers['Content-Type'] = 'text/plain'

            if HAS_HTTPX:
                resp = self.client.post(url, content=encoded, headers=headers)
                success = resp.status_code == 200
            else:
                import urllib.request
                req = urllib.request.Request(url, data=encoded.encode(), headers=headers, method='POST')
                with urllib.request.urlopen(req, timeout=SEND_TIMEOUT, context=self.ssl_context) as resp:
                    success = resp.status == 200

            if success:
                self.log(f"Sent {len(data)} bytes")
            return success
        except Exception as e:
            self.log(f"Send error: {e}")
            return False

    def sse_receiver_thread(self):
        """Receive data via SSE stream (HTTP/2)"""
        stdout_fd = sys.stdout.fileno()

        while self.running:
            try:
                url = f"{self.relay_url}/ssh/stream"
                headers = self.get_headers()
                headers['Accept'] = 'text/event-stream'
                headers['Cache-Control'] = 'no-cache'

                self.log(f"Connecting to SSE stream...")

                if HAS_HTTPX:
                    with httpx.Client(http2=True, verify=False, timeout=None) as stream_client:
                        with stream_client.stream("GET", url, headers=headers) as resp:
                            if resp.status_code != 200:
                                self.log(f"SSE error: {resp.status_code}")
                                time.sleep(1)
                                continue

                            self.log(f"SSE connected (HTTP/{resp.http_version})")

                            for line in resp.iter_lines():
                                if not self.running:
                                    break

                                line = line.strip()
                                if line.startswith('data:'):
                                    encoded = line[5:].strip()
                                    if encoded:
                                        try:
                                            data = base64.b64decode(encoded)
                                            self.last_recv_time = time.time()
                                            os.write(stdout_fd, data)
                                            self.log(f"Received {len(data)} bytes via SSE")
                                        except Exception as e:
                                            self.log(f"Decode error: {e}")
                else:
                    # Fallback: Use polling if httpx not available
                    self.poll_receiver()
                    return

            except Exception as e:
                self.log(f"SSE error: {e}")
                if self.stdin_eof and (time.time() - self.last_recv_time > EOF_WAIT_TIME):
                    self.log("No more data after EOF")
                    self.running = False
                    break
                time.sleep(0.5)

    def poll_receiver(self):
        """Fallback polling receiver (for HTTP/1.1)"""
        import urllib.request
        stdout_fd = sys.stdout.fileno()

        while self.running:
            try:
                url = f"{self.relay_url}/ssh/recv"
                headers = self.get_headers()
                req = urllib.request.Request(url, headers=headers, method='GET')

                with urllib.request.urlopen(req, timeout=5.0, context=self.ssl_context) as resp:
                    if resp.status == 200:
                        encoded = resp.read()
                        if encoded:
                            data = base64.b64decode(encoded)
                            self.last_recv_time = time.time()
                            os.write(stdout_fd, data)
                            self.log(f"Received {len(data)} bytes")
            except Exception as e:
                err = str(e).lower()
                if "timeout" not in err and "timed out" not in err:
                    self.log(f"Poll error: {e}")

            if self.stdin_eof and (time.time() - self.last_recv_time > EOF_WAIT_TIME):
                self.log("No more data after EOF")
                self.running = False
                break
            time.sleep(0.05)

    def run(self):
        """Main loop"""
        # Start receiver thread (SSE or polling)
        receiver = threading.Thread(target=self.sse_receiver_thread, daemon=True)
        receiver.start()

        stdin_fd = sys.stdin.fileno()
        flags = fcntl.fcntl(stdin_fd, fcntl.F_GETFL)
        fcntl.fcntl(stdin_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

        send_buffer = b""
        last_send = 0
        SEND_INTERVAL = 0.01

        try:
            while self.running:
                if self.stdin_eof:
                    time.sleep(0.1)
                    continue

                try:
                    readable, _, _ = select.select([stdin_fd], [], [], 0.01)
                    if readable:
                        try:
                            data = os.read(stdin_fd, 8192)
                            if not data:
                                self.log("EOF on stdin")
                                self.stdin_eof = True
                                if send_buffer:
                                    self.send_data(send_buffer)
                                    send_buffer = b""
                                continue
                            send_buffer += data
                        except BlockingIOError:
                            pass
                except (OSError, ValueError) as e:
                    self.log(f"Select error: {e}")
                    break

                now = time.time()
                if send_buffer and (now - last_send >= SEND_INTERVAL):
                    if self.send_data(send_buffer):
                        send_buffer = b""
                    last_send = now

        except KeyboardInterrupt:
            self.log("Interrupted")
        finally:
            if send_buffer:
                self.send_data(send_buffer)
            self.running = False
            if self.client:
                self.client.close()
            self.log("Exiting")

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <relay_url> [api_key]", file=sys.stderr)
        print(f"  HTTP/2 available: {HAS_HTTPX}", file=sys.stderr)
        sys.exit(1)

    relay_url = sys.argv[1]
    api_key = sys.argv[2] if len(sys.argv) >= 3 else os.environ.get('SSH_RELAY_API_KEY')

    relay = SSHHttp2Relay(relay_url, api_key)
    relay.run()

if __name__ == "__main__":
    main()
