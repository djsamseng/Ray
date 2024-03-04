
import argparse
import base64
import cv2
import json
from multiprocessing import Process, Queue, Value
import pyaudio
import socket
import numpy as np
import time

GLOBAL_HEADER_SIZE = 375 # See StreamingSession.swift headerSize: Int = 375
HEADER_SIZE = 100 # Set in StreamingSession.swift frameHeaderSize: Int = 100
FOOTER_SIZE = 2 # Set in StreamingSession.swift frameFooterSize: Int = 2
ADDR = "169.254.94.129" # 192.168.87.97

def play_audio(stream: pyaudio.Stream, np_data:np.ndarray):
  raw_bytes = np_data.tobytes()
  stream.write(raw_bytes, num_frames=np_data.shape[0])

def receive_audio_p2(queue: Queue, stop_signal_value: Value):
  server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  port = 10002
  addr = ADDR
  server_socket.connect((addr, port))
  recv_global_header(socket=server_socket)
  p = pyaudio.PyAudio()
  stream = p.open(
    format=pyaudio.paInt16,
    channels=1,
    rate=44100,
    output=True)
  while stop_signal_value.value == 0:
    try:
      message = recvall(server_socket)
      data = json.loads(message)
      audio_data = data["audioData"]
      np_audio = np.frombuffer(base64.b64decode(audio_data), dtype=np.int16)
      play_audio(stream=stream, np_data=np_audio)
    except Exception as e:
      print("Failed to parse audio:", e)

def recv_global_header(socket, global_header_size=GLOBAL_HEADER_SIZE):
  bytes_left_to_receive = global_header_size
  while True:
    chunk = socket.recv(bytes_left_to_receive)
    bytes_left_to_receive -= len(chunk)
    if bytes_left_to_receive == 0:
      return

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
        footer = socket.recv(footer_size)
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
        return chunk


def livemode(skip: int, do_record: bool, armode: bool):
  do_play_audio = False
  if do_play_audio:
    queue = Queue()
    stop_signal = Value('i', 0)
    p2 = Process(target=receive_audio_p2, args=(queue, stop_signal))
    p2.start()
  server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  port = 10001
  if True:
    # TCP - ask to connect to existing host on addr
    addr = ADDR
    print("CONNECTING TO:", addr)
    server_socket.connect((addr, port))
    print("Did connect")
  else:
    # UDP
    addr = "169.254.139.123"
    server_socket.bind((addr, port))

  did_receive_header = False
  while not did_receive_header:
    try:
      recv_global_header(socket=server_socket)
      did_receive_header = True
    except:
      pass
  print("Did get headers")
  itr = 0
  recording = False
  while True:
    message = recvall(server_socket)
    if len(message) == 0:
      print("Quitting due to empty message")
      break
    try:
      data = json.loads(message)
      color_image = data["colorImage"]
      depth_image = data["depthImage"]
      if "userAcceleration" in data:
        userAcceleration = np.array(data["userAcceleration"], dtype=np.float32)
        #print(data["userAcceleration"])
      if "cameraTranslation" in data:
        #print(data["cameraTranslation"])
        camera_translation = np.array(data["cameraTranslation"], dtype=np.float32)
        camera_position = camera_translation[0, 3, :]
        # [right/left, up/down, back/forward]
        # See https://stackoverflow.com/questions/45437037/arkit-what-do-the-different-columns-in-transform-matrix-represent
      np_color = np.frombuffer(base64.b64decode(color_image), dtype=np.uint8)
      im = cv2.imdecode(np_color, cv2.IMREAD_COLOR)
      cv2.imshow("Color", im)
      if armode:
        # 256, 192
        np_depth = np.frombuffer(base64.b64decode(depth_image), dtype=np.float32).reshape((-1, 256)).astype(np.float32)
        scaled_depth = np_depth / (np.max(np_depth) - np.min(np_depth))
        cv2.imshow("Depth", np_depth)
        cv2.imshow("Scaled Depth", scaled_depth)
      else:
        # 320, 240
        np_depth = np.frombuffer(base64.b64decode(depth_image), dtype=np.float32).reshape((-1, 320))#.astype(np.float32)
        scaled_depth = (np_depth - np.min(np_depth)) / (np.max(np_depth) - np.min(np_depth))
        cv2.imshow("Depth", np_depth)
        cv2.imshow("Scaled Depth", scaled_depth)

      if itr >= 100 and do_record and not recording:
        print("===== Recording =====")
        recording = True
      if recording and itr % 10 == 0:
        pass
        #np.savez("depth"+str(itr), color=im, depth=im_depth, camera=camera_translation)
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

  if do_play_audio:
    stop_signal.value = 1
    while not queue.empty():
      queue.get()
    p2.join()
  cv2.destroyAllWindows()

def show_recordings():
  filenames = ["depth"+str(itr)+".npz" for itr in np.arange(100, 201, 10)]
  for filename in filenames:
    data = np.load(filename)
    print(data["camera"][0,3,:])
    cv2.imshow("Color", data["color"])
    cv2.waitKey(500)
  cv2.destroyAllWindows()

def parse_args():
  parser = argparse.ArgumentParser()
  parser.add_argument("--record", dest="record", action="store_true")
  parser.add_argument("--playaudio", dest="playaudio", action="store_true")
  parser.add_argument("--showrecordings", dest="showrecordings", action="store_true")
  parser.add_argument("--armode", dest="armode", action="store_true")
  parser.add_argument("--skip", dest="skip", default=3, help="The number of frames to skip when showing the live images. This allows cv2.waitKey(1) to not take too much time and allowing the stream to keep up")
  return parser.parse_args()

def main():
  args = parse_args()
  if args.showrecordings:
    show_recordings()
  elif args.playaudio:
    queue = Queue()
    stop_signal = Value('i', 0)
    receive_audio_p2(queue, stop_signal)
  else:
    livemode(skip=args.skip, do_record=args.record, armode=args.armode)

if __name__ == "__main__":
  main()
