
import base64
import cv2
import json
import socket
import numpy as np



HEADER_SIZE = 100 # Set in StreamingSession.swift frameHeaderSize: Int = 100

def recvall(socket, buffer_size=4096, header_size=HEADER_SIZE):
  fragments = []
  bytes_left_to_receive = 0
  got_header = False

  while True:
    if got_header:
      chunk = socket.recv(bytes_left_to_receive)
      fragments.append(chunk)
      bytes_left_to_receive -= len(chunk)

      if bytes_left_to_receive == 0:
        return b''.join(fragments)
    else:
      chunk = socket.recv(header_size)
      s = chunk.decode("utf-8")
      parts = s.split("\r\n")
      if len(parts) == 6 and parts[2] == "Content-Type: application/json":
        got_header = True
        message_size = int(parts[3].split(" ")[1])
        bytes_left_to_receive = message_size

def main():
  server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  port = 10001
  if True:
    # TCP
    addr = "192.168.1.211"
    server_socket.connect((addr, port))
  else:
    # UDP
    addr = ""
    server_socket.bind((addr, port))

  while True:
    message = recvall(server_socket)
    try:
      data = json.loads(message)
      color_image = data["colorImage"]
      depth_image = data["depthImage"]
      np_color = np.fromstring(base64.b64decode(color_image), dtype=np.uint8)
      np_depth = np.fromstring(base64.b64decode(depth_image), dtype=np.uint8)
      im = cv2.imdecode(np_color, cv2.IMREAD_COLOR)
      im_depth = cv2.imdecode(np_depth, cv2.IMREAD_COLOR)
      cv2.imshow("Color", im)
      cv2.imshow("Depth", im_depth)
      ret = cv2.waitKey(1)
      if ret >= 0:
        break
    except Exception as e:
      print("Failed to load json:", e)
      print(message)


if __name__ == "__main__":
  main()
