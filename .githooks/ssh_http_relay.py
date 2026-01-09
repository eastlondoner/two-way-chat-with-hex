#!/usr/bin/env python3
"""
SSH-over-HTTP relay client.
Used as ProxyCommand to tunnel SSH through HTTP POST/GET requests.
Designed for environments with HTTP proxies that block direct SSH connections.

Usage: ssh -o ProxyCommand="python3 ssh_http_relay.py <relay_url> [api_key]" user@host

Environment variables:
  SSH_RELAY_API_KEY: API key for relay authentication (optional, for DoS prevention)
  DEBUG: Set to '1' for verbose logging

Security: SSH key-based authentication handles the real security.
The API key just prevents random scanners from wasting server resources.
"""

import sys
import os
import base64
import select
import time
import threading
import urllib.request
import urllib.error
import uuid
import fcntl
import ssl

POLL_INTERVAL = 0.05  # 50ms between recv polls
RECV_TIMEOUT = 5.0
SEND_TIMEOUT = 5.0
EOF_WAIT_TIME = 2.0  # Wait 2s after EOF for remaining data

# Disable SSL verification for MITM proxy environments
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

class SSHHttpRelay:
    def __init__(self, relay_url, api_key=None):
        self.relay_url = relay_url.rstrip('/')
        self.session_id = str(uuid.uuid4())
        self.api_key = api_key
        self.running = True
        self.stdin_eof = False
        self.last_recv_time = time.time()
        self.debug = os.environ.get('DEBUG', '') == '1'

    def log(self, msg):
        if self.debug:
            print(f"[RELAY] {msg}", file=sys.stderr)
            sys.stderr.flush()

    def get_headers(self):
        """Generate request headers including API key if configured."""
        headers = {
            'X-Session-ID': self.session_id,
        }
        if self.api_key:
            headers['X-API-Key'] = self.api_key
        return headers

    def send_data(self, data):
        """Send data to SSH via HTTP POST"""
        try:
            encoded = base64.b64encode(data).decode('ascii')
            url = f"{self.relay_url}/ssh/send"

            headers = self.get_headers()
            headers['Content-Type'] = 'text/plain'

            req = urllib.request.Request(
                url,
                data=encoded.encode('utf-8'),
                headers=headers,
                method='POST'
            )
            with urllib.request.urlopen(req, timeout=SEND_TIMEOUT, context=ssl_context) as resp:
                self.log(f"Sent {len(data)} bytes")
                return resp.status == 200
        except urllib.error.HTTPError as e:
            if e.code == 401:
                self.log("Authentication failed - check SSH_RELAY_API_KEY")
                self.running = False
            else:
                self.log(f"Send HTTP error: {e.code}")
            return False
        except Exception as e:
            self.log(f"Send error: {e}")
            return False

    def recv_data(self):
        """Receive data from SSH via HTTP GET"""
        try:
            url = f"{self.relay_url}/ssh/recv"
            headers = self.get_headers()

            req = urllib.request.Request(
                url,
                headers=headers,
                method='GET'
            )
            with urllib.request.urlopen(req, timeout=RECV_TIMEOUT, context=ssl_context) as resp:
                if resp.status == 200:
                    encoded = resp.read()
                    if encoded:
                        data = base64.b64decode(encoded)
                        self.log(f"Received {len(data)} bytes")
                        return data
        except urllib.error.HTTPError as e:
            if e.code == 401:
                self.log("Authentication failed - check SSH_RELAY_API_KEY")
                self.running = False
            elif e.code != 204:
                self.log(f"Recv HTTP error: {e.code}")
        except Exception as e:
            err_str = str(e).lower()
            if "timed out" not in err_str and "timeout" not in err_str:
                self.log(f"Recv error: {e}")
        return b""

    def receiver_thread(self):
        """Thread to poll for received data and write to stdout"""
        stdout_fd = sys.stdout.fileno()
        while self.running:
            data = self.recv_data()
            if data:
                self.last_recv_time = time.time()
                try:
                    os.write(stdout_fd, data)
                except Exception as e:
                    self.log(f"Write error: {e}")
                    self.running = False
                    break
            else:
                # If stdin EOF and no data for a while, exit
                if self.stdin_eof and (time.time() - self.last_recv_time > EOF_WAIT_TIME):
                    self.log("No more data after EOF, exiting")
                    self.running = False
                    break
                time.sleep(POLL_INTERVAL)

    def run(self):
        """Main loop - read from stdin, write to HTTP relay"""
        # Start receiver thread
        receiver = threading.Thread(target=self.receiver_thread, daemon=True)
        receiver.start()

        stdin_fd = sys.stdin.fileno()

        # Set stdin to non-blocking
        flags = fcntl.fcntl(stdin_fd, fcntl.F_GETFL)
        fcntl.fcntl(stdin_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

        send_buffer = b""
        last_send = 0
        SEND_INTERVAL = 0.01  # Batch sends every 10ms

        try:
            while self.running:
                # If stdin EOF, just sleep and let receiver thread do its thing
                if self.stdin_eof:
                    time.sleep(0.1)
                    continue

                # Check for data from stdin
                try:
                    readable, _, _ = select.select([stdin_fd], [], [], 0.01)
                    if readable:
                        try:
                            data = os.read(stdin_fd, 8192)
                            if not data:
                                self.log("EOF on stdin")
                                self.stdin_eof = True
                                # Send any remaining buffered data
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

                # Send batched data
                now = time.time()
                if send_buffer and (now - last_send >= SEND_INTERVAL):
                    if self.send_data(send_buffer):
                        send_buffer = b""
                    last_send = now

        except KeyboardInterrupt:
            self.log("Interrupted")
        finally:
            # Send any remaining data
            if send_buffer:
                self.send_data(send_buffer)
            self.running = False
            self.log("Exiting")

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <relay_url> [api_key]", file=sys.stderr)
        print(f"  Or set SSH_RELAY_API_KEY environment variable", file=sys.stderr)
        sys.exit(1)

    relay_url = sys.argv[1]

    # Get API key from argument or environment
    api_key = None
    if len(sys.argv) >= 3:
        api_key = sys.argv[2]
    elif os.environ.get('SSH_RELAY_API_KEY'):
        api_key = os.environ.get('SSH_RELAY_API_KEY')

    relay = SSHHttpRelay(relay_url, api_key)
    relay.run()

if __name__ == "__main__":
    main()
