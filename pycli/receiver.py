
import base64
import cv2
import json
import socket
import numpy as np

HEADER_SIZE = 100 # Set in StreamingSession.swift frameHeaderSize: Int = 100
FOOTER_SIZE = 2 # Set in StreamingSession.swift frameFooterSize: Int = 2

def recvall(socket, buffer_size=4096, header_size=HEADER_SIZE, footer_size=FOOTER_SIZE):
  fragments = []
  bytes_left_to_receive = 0
  got_header = False
  times = 0
  while True:
    if got_header:
      chunk = socket.recv(bytes_left_to_receive)
      fragments.append(chunk)
      bytes_left_to_receive -= len(chunk)

      if bytes_left_to_receive == 0:
        socket.recv(2)
        return b''.join(fragments)
    else:
      chunk = socket.recv(header_size)
      s = chunk.decode("utf-8")
      parts = s.split("\r\n")
      if len(parts) == 6 and parts[2] == "Content-Type: application/json":
        got_header = True
        message_size = int(parts[3].split(" ")[1])
        bytes_left_to_receive = message_size
      else:
        print("Unknown:", chunk)

def main(skip: int):
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

  itr = 0
  do_record = True
  recording = False
  while True:
    message = recvall(server_socket)
    try:
      data = json.loads(message)
      color_image = data["colorImage"]
      depth_image = data["depthImage"]
      camera_translation = np.array(data["cameraTranslation"], dtype=np.float32)
      # camera_position = camera_translation[0, 3, :]
      # [right/left, up/down, back/forward]
      # See https://stackoverflow.com/questions/45437037/arkit-what-do-the-different-columns-in-transform-matrix-represent
      np_color = np.frombuffer(base64.b64decode(color_image), dtype=np.uint8)
      np_depth = np.frombuffer(base64.b64decode(depth_image), dtype=np.uint8)
      im = cv2.imdecode(np_color, cv2.IMREAD_COLOR)
      im_depth = cv2.imdecode(np_depth, cv2.IMREAD_COLOR)
      cv2.imshow("Color", im)
      cv2.imshow("Depth", im_depth)

      if itr >= 100 and do_record and not recording:
        print("===== Recording =====")
        recording = True
      if recording and itr % 10 == 0:
        np.savez("depth"+str(itr), color=im, depth=im_depth, camera=camera_translation)
      if itr >= 200 and do_record:
        break

      itr += 1
      if itr % (skip+1) == 0:
        ret = cv2.waitKey(1)
        if ret >= 0:
          break
    except Exception as e:
      print("Failed to load json:", e)
      print(message)
  cv2.destroyAllWindows()

def show_recordings():
  filenames = ["depth"+str(itr)+".npz" for itr in np.arange(100, 201, 10)]
  for filename in filenames:
    data = np.load(filename)
    print(data["camera"][0,3,:])
    cv2.imshow("Color", data["color"])
    cv2.waitKey(500)
  cv2.destroyAllWindows()

if __name__ == "__main__":
  show_recordings()
  #main(skip=3)
